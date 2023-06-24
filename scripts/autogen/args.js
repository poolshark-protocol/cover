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
        twapSource: "0x0765377b610233BEfC6beA29C7697A7B47839a2D", // uniswapV3Source
        curveMath: "0x0765377b610233BEfC6beA29C7697A7B47839a2D", // constantProduct
        inputPool: "0x117e312b6C48211Db25d3b731171A311A2E1AdA6", // uniswapV3PoolMock
        owner: "0xaa22D9F5Fb1436c64584a6C7efB95aFde1557de1", // coverPoolManager
        token0: "0x6774be1a283Faed7ED8e40463c40Fb33A8da3461", // token0
        token1: "0xC26906E10E8BDaDeb2cf297eb56DF59775eE52c4", // token1
        tickSpread: "20", // tickSpread
        twapLength: "5" // twapLength
    }
];