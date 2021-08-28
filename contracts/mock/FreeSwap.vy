# @version 0.2.15
from .. import StableFlash
from vyper.interfaces import ERC20


@external
def freeSwap(stableFlash: address, token: address, amount: uint256):
    ERC20(token).transferFrom(msg.sender, self, amount)
    ERC20(token).approve(stableFlash, amount)
    # Someone who wants to swap free would likely use
    # another output token, so this is just here
    # for testing reentrancy protection.
    StableFlash(stableFlash).deposit(token, amount / 2)
    StableFlash(stableFlash).deposit(token, amount / 2)
    StableFlash(stableFlash).withdraw(token, amount)
