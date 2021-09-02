# @version 0.2.16
from vyper.interfaces import ERC20

# Maximum number of tokens supported by the strategy
MAX_TOKENS: constant(uint256) = 4


interface ILendingPool:
    def withdraw(asset: address, amount: uint256, receiver: address) -> uint256:
        nonpayable


interface IProtocolDataProvider:
    def getReserveTokensAddresses(asset: address) -> (address, address, address):
        view


managers: public(address[2])

# Lending
lendingPool: public(ILendingPool)
dataProvider: public(IProtocolDataProvider)

balances: public(HashMap[address, uint256])

tokens: public(address[MAX_TOKENS])


@external
def __init__(_manager: address, _lendingPool: address, _dataProvider: address):
    self.managers[0] = _manager
    self.lendingPool = ILendingPool(_lendingPool)
    self.dataProvider = IProtocolDataProvider(_dataProvider)


@external
def deposit(token: address, amount: uint256):
    assert msg.sender in self.managers
    assert token in self.tokens
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
def withdraw(token: address, amount: uint256, receiver: address) -> uint256:
    assert msg.sender in self.managers
    self.balances[token] -= amount
    return self.lendingPool.withdraw(token, amount, receiver)


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
    return self._underlyingBalances(token) - self.balances[token]


@external
@view
def pendingRewards() -> uint256[MAX_TOKENS]:
    reward: uint256[MAX_TOKENS] = empty(uint256[MAX_TOKENS])
    for i in range(MAX_TOKENS):
        if self.tokens[i] != ZERO_ADDRESS:
            reward[i] = (
                self._underlyingBalances(self.tokens[i]) - self.balances[self.tokens[i]]
            )

    return reward


@external
def updateTokens(token: address[MAX_TOKENS]):
    assert msg.sender in self.managers
    self.tokens = token
