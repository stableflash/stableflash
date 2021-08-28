from brownie import *
import brownie

def test_transfer(stable_flash):
    stable_flash.transfer(a[1], 1e18)
    assert stable_flash.balanceOf.call(a[1]) == 1e18

def test_transfer_from(stable_flash):
    stable_flash.approve(a[1], 1e18)
    stable_flash.transferFrom(a[0], a[2], 1e18, {'from': a[1]})
    assert stable_flash.balanceOf.call(a[2]) == 1e18

def test_flash_mint(stable_flash, flash_minter):
    stable_flash.flashLoan(
        flash_minter,
        stable_flash,
        1e18,
        b""
    )

def test_flash_mint_with_fee(stable_flash, flash_minter):
    stable_flash.updateFees(0, 1, 1000)
    with brownie.reverts():
        stable_flash.flashLoan(
            flash_minter,
            stable_flash,
            1e18,
            b"",
        {'from': a[1]})
    
    stable_flash.transfer(a[1], 1e18 / 1000)
    stable_flash.flashLoan(
        flash_minter, 
        stable_flash,
        1e18,
        b"",
    {'from': a[1]})

def test_fake_flash_mint(stable_flash, fake_minter):
    with brownie.reverts():
        stable_flash.flashLoan(
            fake_minter,
            stable_flash,
            1e18,
            b""
        )

def test_deposit_stablecoin(stable_flash, stablecoin):
    stable_flash.allowToken(stablecoin, True)
    stablecoin.approve(stable_flash, 1e18)
    pre_deposit = stable_flash.balanceOf.call(a[0])
    stable_flash.deposit(stablecoin, 1e18)
    assert stable_flash.balanceOf.call(a[0]) == pre_deposit + 1e18

def test_withdraw_stablecoin(stable_flash, stablecoin):
    stable_flash.allowToken(stablecoin, True)
    stablecoin.approve(stable_flash, 1e18)
    stablecoin_balance = stablecoin.balanceOf.call(a[0])
    stable_flash.deposit(stablecoin, 1e18)
    stable_flash.withdraw(stablecoin, 1e18)
    assert stable_flash.balanceOf.call(a[0]) == stablecoin_balance

def test_swap(stable_flash, stablecoin):
    stable_flash.allowToken(stablecoin, True)
    stablecoin.approve(stable_flash, 1e18)
    stablecoin_balance = stablecoin.balanceOf.call(a[0])
    stable_flash.swap(stablecoin, stablecoin, 1e18)
    assert stablecoin.balanceOf.call(a[0]) == stablecoin_balance

def test_swap_not_allowed(stable_flash, stablecoin):
    with brownie.reverts():
        stable_flash.swap(stablecoin, stablecoin, 1e18)

def test_swap_fee(stable_flash, stablecoin):
    stable_flash.updateFees(3, 1, 100)
    stablecoin.approve(stable_flash, 1e18)
    stablecoin.transfer(a[1], 999e18)
    stable_flash.allowToken(stablecoin, True)
    balance_before_swap = stable_flash.balanceOf.call(a[0])
    stable_flash.swap(stablecoin, stablecoin, 1e18)
    assert stable_flash.balanceOf.call(a[0]) >= balance_before_swap + 1e18 * 3 / 1000


def test_free_swap(stable_flash, free_swap, stablecoin):
    stablecoin.approve(free_swap, 1e18)
    stable_flash.allowToken(stablecoin, True)
    with brownie.reverts():
        free_swap.freeSwap(stable_flash, stablecoin, 1e18)