# @version 0.2.16
from vyper.interfaces import ERC20


interface ILendingPool:
    def withdraw(asset: address, amount: uint256, receiver: address) -> uint256:
        nonpayable


interface IProtocolDataProvider:
    def getReserveTokensAddresses(asset: address) -> (address, address, address):
        view


manager: public(address)

# Lending
lendingPool: public(ILendingPool)
dataProvider: public(IProtocolDataProvider)

balances: public(HashMap[address, uint256])


@external
def __init__(_manager: address, _lendingPool: address, _dataProvider: address):
    self.manager = _manager
    self.lendingPool = ILendingPool(_lendingPool)
    self.dataProvider = IProtocolDataProvider(_dataProvider)


@external
def deposit(token: address, amount: uint256):
    ERC20(token).transferFrom(msg.sender, self, amount)
    self.balances[token] += amount

    # Check ERC20 allowance to deposit into Aave
    allowance: uint256 = ERC20(token).allowance(self, self.lendingPool.address)

    if amount > allowance:
        ERC20(token).approve(self.lendingPool.address, MAX_UINT256)

    raw_call(
        self.lendingPool.address,
        concat(
            method_id("deposit(address,uint256,address,uint16)"),
            convert(token, bytes32),
            convert(amount, bytes32),
            convert(self, bytes32),
            convert(0, bytes32),
        ),
    )


@external
def withdraw(token: address, amount: uint256, receiver: address):
    assert msg.sender == self.manager
    self.balances[token] -= amount
    self.lendingPool.withdraw(token, amount, receiver)


@internal
@view
def _underlyingBalances(token: address) -> uint256:
    return ERC20(self.dataProvider.getReserveTokensAddresses(token)[0]).balanceOf(self)


@external
@view
def balanceOf(token: address) -> uint256:
    return self._underlyingBalances(token)


@external
@view
def rewards(token: address) -> uint256:
    return self.balances[token] - self._underlyingBalances(token)
