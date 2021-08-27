import pytest
from brownie import *


@pytest.fixture
def stable_flash():
    yield a[0].deploy(StableFlash, 1000)

@pytest.fixture
def stablecoin():
    yield a[0].deploy(StableFlash, 1000)

@pytest.fixture
def flash_minter():
    yield a[0].deploy(FlashMinter)

@pytest.fixture
def fake_minter():
    yield a[0].deploy(FakeMinter)