module.exports = {
    skipFiles: [
        'test', 
        'utils',
        'libraries/TickMap.sol', 
        'libraries/EpochMap.sol',
        'CoverPoolRouter.sol'
    ],
    configureYulOptimizer: true,
}
