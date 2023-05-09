module.exports = [
    {
        config: {
            minAmountPerAuction: ethers.utils.parseUnits("1", 18),
            auctionLength: "5",
            blockTime: "1000",
            syncFee: "0",
            fillFee: "0",
            minPositionWidth: "1",
            minAmountLowerPriced: true
        },
        twapSource: "0x96c2815F7c750eb15d8d85c522dfF85EadAA1cD5", // uniswapV3Source
        curveMath: "0xFA807ce77b103129597CcE4a7Bf7F504F9e7BD9e", // constantProduct
        inputPool: "0xAeBC1Ff701c704488e1A31651dCDB5DBBF2498e8", // uniswapV3PoolMock
        owner: "0xC2271A012fbBA8098e569bE9fA893a1255D73b0f", // coverPoolManager
        token0: "0x414B73f989e7cA0653b5C98186749a348405E6D5", // token0
        token1: "0xd50B04a5693F2d026D589Bf239609Bf5B8346AdC", // token1
        tickSpread: "20", // tickSpread
        twapLength: "5" // twapLength
    }
];