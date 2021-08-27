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
    stable_flash.flashMint(
        flash_minter,
        stable_flash,
        1e18,
        b""
    )

def test_fake_flash_mint(stable_flash, fake_minter):
    with brownie.reverts():
        stable_flash.flashMint(
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
    assert stable_flash.balanceOf.call(a[0]) == stablecoin_balance

def test_swap_not_allowed(stable_flash, stablecoin):
    with brownie.reverts():
        stable_flash.swap(stablecoin, stablecoin, 1e18)