module.exports = [
    {
        config: {
            minAmountPerAuction: ethers.utils.parseUnits('0'),
            auctionLength: "5",
            blockTime: "1000",
            syncFee: "0",
            fillFee: "0",
            minPositionWidth: "1",
            minAmountLowerPriced: true
        },
        twapSource: "0x38Cb2D75C1B97f112E3e91a2E97DcB9118fbF140", // uniswapV3Source
        curveMath: "0x38Cb2D75C1B97f112E3e91a2E97DcB9118fbF140", // constantProduct
        inputPool: "0xFb5B89C5115879529dfdBf19ab7Dd0FE38e333dB", // uniswapV3PoolMock
        owner: "0x64BA950eed56d2341632070Cad0f6ff7afaf6372", // coverPoolManager
        token0: "0x6774be1a283Faed7ED8e40463c40Fb33A8da3461", // token0
        token1: "0xC26906E10E8BDaDeb2cf297eb56DF59775eE52c4", // token1
        tickSpread: "20", // tickSpread
        twapLength: "5" // twapLength
    }
];