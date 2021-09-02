from brownie import *
import pytest

pytestmark = [pytest.mark.require_network("mainnet-fork")]

def test_deposit_strategy(strategy):
    whale = {'from': accounts.at("0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503", force=True)}
    dai = StableFlash.at("0x6b175474e89094c44da98b954eedeac495271d0f") # ERC20 interface

    tokens = [ZERO_ADDRESS] * 4
    tokens[0] = dai

    dai.approve(strategy, 100_000e18, whale)
    strategy.updateTokens(tokens, whale)
    strategy.deposit(dai, 100_000e18, whale)

    chain.sleep(86400)
    chain.mine()

    # Rewards needs to exceed 0 after 1 day, otherwise what is the point of strategy?
    assert strategy.rewards.call(dai)/1e18 > 0
    assert strategy.pendingRewards.call()[0] == strategy.rewards.call(dai)


def test_withdraw_strategy(strategy):
    whale = {'from': accounts.at("0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503", force=True)}
    dai = StableFlash.at("0x6b175474e89094c44da98b954eedeac495271d0f")
    
    test_deposit_strategy(strategy)

    balance_before_withdraw = dai.balanceOf.call(whale['from'])
    balance_withdrawn = strategy.withdraw(dai, 100_000e18, whale['from'], whale).return_value
    assert dai.balanceOf.call(whale['from']) == balance_before_withdraw + balance_withdrawn