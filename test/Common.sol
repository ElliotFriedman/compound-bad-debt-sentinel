pragma solidity 0.8.13;

library Common {
    /// compound flash mint folding yearn vault address
    address constant public yearn = 0x01d127D90513CCB6071F83eFE15611C4d9890668;

    /// compound morpho main address
    address constant public morpho = 0x8888882f8f843896699869179fB6E4f7e3B58888;

    /// USDC cToken
    address constant public CUSDC = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;

    /// DAI cToken
    address constant public CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;

    /// ETH cToken
    address constant public CETH = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;

    /// USDC address
    address constant public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// DAI address
    address constant public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    /// compound comptroller address
    address constant public comptroller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
}
