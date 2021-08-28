# @version 0.2.15
from vyper.interfaces import ERC20

implements: ERC20


event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    amount: uint256


event Approval:
    sender: indexed(address)
    receiver: indexed(address)
    amount: uint256


interface IFlashMinter:
    def onFlashLoan(
        sender: address,
        token: address,
        amount: uint256,
        fee: uint256,
        data: Bytes[1028],
    ):
        nonpayable


# Allowed stablecoins for the deposit
allowed: public(HashMap[address, bool])
# Reserves of the stablecoin
reserves: public(HashMap[address, uint256])
# Fees
swapFee: public(uint256)
flashFee: public(uint256)
feeDivider: public(uint256)

interaction: HashMap[uint256, HashMap[address, bool]]

# ERC20 details
name: public(String[64])
symbol: public(String[32])
balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
totalSupply: public(uint256)
decimals: public(uint256)
admin: public(address)

NAME: constant(String[64]) = "stableflash.xyz"
SYMBOL: constant(String[32]) = "STFL"
DECIMALS: constant(uint256) = 18


@external
def __init__(_supply: uint256):
    self.admin = msg.sender
    self.name = NAME
    self.symbol = SYMBOL
    supply: uint256 = _supply * 10 ** DECIMALS
    self.totalSupply = supply
    self.decimals = DECIMALS

    self.flashFee = 0
    self.swapFee = 0
    self.feeDivider = 1

    if supply > 0:
        self.balanceOf[msg.sender] = supply
        log Transfer(ZERO_ADDRESS, msg.sender, supply)


@internal
def _mint(receiver: address, amount: uint256):
    self.balanceOf[receiver] += amount
    self.totalSupply += amount

    log Transfer(ZERO_ADDRESS, receiver, amount)


@internal
def _burn(sender: address, amount: uint256):
    self.balanceOf[sender] -= amount
    self.totalSupply -= amount

    log Transfer(sender, ZERO_ADDRESS, amount)


@internal
def _transfer(sender: address, receiver: address, amount: uint256):
    self.balanceOf[sender] -= amount
    self.balanceOf[receiver] += amount

    log Transfer(sender, receiver, amount)


@external
@nonreentrant("swap")
def deposit(token: address, amount: uint256):
    """
    @notice
        Deposit token to receive amount in your balance
    @param token
        Token to deposit
    @param amount
        Amount to mint and transfer in token
    """
    assert self.allowed[token]
    # It it aims to prevent deposits & withdraws in the same block.
    # Flash minters can use swap() if they
    # want to convert their funds.
    assert not self.interaction[block.number][msg.sender]
    self.interaction[block.number][msg.sender] = True

    ERC20(token).transferFrom(msg.sender, self, amount)
    self.reserves[token] += amount
    self.balanceOf[msg.sender] += amount


@external
@nonreentrant("swap")
def withdraw(token: address, amount: uint256):
    """
    @notice
        Withdraw balance in token
    @param token
        Token to receive
    @param amount
        Amount to burn in balance and receive in token
    """
    assert self.allowed[token]
    assert not self.interaction[block.number][msg.sender]
    self.interaction[block.number][msg.sender] = True

    self.balanceOf[msg.sender] -= amount
    ERC20(token).transfer(msg.sender, amount)


@external
def swap(tokenIn: address, tokenOut: address, amount: uint256):
    """
    @notice
        Swap tokenIn to tokenOut with no fees
    @param tokenIn
        Token you currently have
    @param tokenOut
        Token you want to have
    @param amount
        Amount you'll send & receive (stable swap)
    """
    assert self.allowed[tokenIn] and self.allowed[tokenOut]
    ERC20(tokenIn).transferFrom(msg.sender, self, amount)
    # Calculate the swap fee
    fee: uint256 = amount * self.swapFee / self.feeDivider
    # Transfers the fee to admin
    # TODO: Replace admin with DAO treasury
    self._mint(self.admin, fee)
    self.reserves[tokenIn] += amount
    # Amount - fee is sent to msg.sender
    self.reserves[tokenOut] -= amount - fee
    ERC20(tokenOut).transfer(msg.sender, amount - fee)


@external
def approve(receiver: address, amount: uint256) -> bool:
    """
    @notice
        Approve funds to receiver
    @param receiver
        Receiver that will be able to spend funds
    @param amount
        Amount of funds to allow receiver for usage
    """
    self.allowance[msg.sender][receiver] += amount
    log Approval(msg.sender, receiver, amount)
    return True


@external
def transfer(receiver: address, amount: uint256) -> bool:
    """
    @notice
        Transfer funds to receiver
    @param receiver
        Address that will receive funds
    @param amount
        Amount of funds to transfer
    """
    self._transfer(msg.sender, receiver, amount)
    return True


@external
def transferFrom(owner: address, receiver: address, amount: uint256) -> bool:
    """
    @notice
        Transfer from owner to receiver
    @param owner
        Address that holds funds
    @param receiver
        Address that will receive funds
    @param amount
        Amount of funds to transfer
    @dev
        You need to have allowance from receiver
    """
    self.allowance[owner][msg.sender] -= amount
    self._transfer(owner, receiver, amount)
    return True


@internal
def _flashFee(amount: uint256) -> uint256:
    return amount * self.flashFee / self.feeDivider


@external
@nonreentrant("lock")
def flashLoan(
    receiver: address, token: address, amount: uint256, data: Bytes[1028]
) -> bool:
    """
    @notice
        Flash mint tokens and return in same transaction
    @param receiver
        Address that executes onFlashLoan operation
    @param token
        Token to receive
    @param amount
        Amount of tokens to receive
    @param data
        Data to execute with flash loan operation
    """
    assert token == self
    fee: uint256 = self._flashFee(amount)

    self._mint(msg.sender, amount)
    IFlashMinter(receiver).onFlashLoan(msg.sender, token, amount, fee, data)
    self._burn(msg.sender, amount + fee)
    self._mint(self.admin, fee)

    return True


@external
def allowToken(token: address, _allowed: bool):
    """
    @notice
        Allow token to be deposited
    @param token
        Token to change status
    @param _allowed
        Whether to allow deposits or not
    """
    assert msg.sender == self.admin
    self.allowed[token] = _allowed


@external
def updateFees(
    _swapFee: uint256,
    _flashFee: uint256,
    _feeDivider: uint256,
):
    """
    @notice
        Update fees for swap and flash mint
    @param _swapFee
        Swap fee
    @param _flashFee
        Flash mint fee
    @param _feeDivider
        Fee divider
    """
    assert msg.sender == self.admin
    self.swapFee = _swapFee
    self.flashFee = _flashFee
    self.feeDivider = _feeDivider
