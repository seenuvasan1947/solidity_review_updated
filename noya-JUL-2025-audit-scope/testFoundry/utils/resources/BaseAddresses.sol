// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

contract BaseAddresses {
    // DeFi Ecosystem
    address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public uniV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // ERC20s
    address public USDC = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address public USDbC = address(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA);
    address public DAI = address(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);
    address public SNX = 0x22e6966B799c4D5B13BE962E1D117b56327FDa66;
    address public SUSDC = 0xC74eA762cF06c9151cE074E6a569a5945b6302E7;
    address public cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address public wstETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address public WETH = 0x4200000000000000000000000000000000000006;

    // Chainlink Datafeeds
    address public USDC_USD_FEED = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address public DAI_USD_FEED = 0x591e79239a7d679378eC8c847e5038150364C78F;
    address public SNX_USD_FEED = 0xe3971Ed6F1A5903321479Ef3148B5950c0612075;

    // Aerodrome
    address public aerodrome_USDC_DAI_Pool =
        0x67b00B46FA4f4F24c03855c5C8013C0B938B3eEc;
    address public aerodromeRouter = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public aerodromeVoter = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;

    //
    address public USDC_Whale = 0x20FE51A9229EEf2cF8Ad9E89d91CAb9312cF3b7A;

    // Syntetix
    address public SNXv3Core = 0x32C222A9A159782aFD7529c87FA34b96CA72C696;

    address public morphoBlue = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    string public RPC_URL =
        "https://base-mainnet.g.alchemy.com/v2/YTZ4co0ktED8_pxzfX77Lqg9Z2z4SCX_";
    uint256 public startingBlock = 15_759_872;
}
