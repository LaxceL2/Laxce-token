const { ethers, upgrades} = require("hardhat");
require('@openzeppelin/hardhat-upgrades');


async function main() {
  //USDT Token Contract deplopyment

  // const USDT = await ethers.getContractFactory("USDT");
  // const USDT_ = await USDT.deploy();

  // const USDTAddress = await USDT_.getAddress();

  // console.log(`USDT Token Contract Address: ${USDTAddress}`);

  const Laxce = await ethers.getContractFactory("Laxce");
  const Laxce_ = await upgrades.deployProxy(Laxce, {
    initializer: "initialize",
    kind: "uups",
  });

  const LaxceTokenAddress = await Laxce_.getAddress();

  console.log(
    `LAXCE Token Contract Address: ${LaxceTokenAddress}`
  );

  const USDTAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
  // const LaxceTokenAddress = "0x2E8e667f72790C11270ba98402E25CBf171965d6";

  const LaxceCrowdSale = await ethers.getContractFactory("LaxceCrowdSale");
  const LaxceCrowdSale_ = await upgrades.deployProxy(LaxceCrowdSale, [
    "40000", 
    LaxceTokenAddress,
    USDTAddress], {
    initializer: "initialize",
    kind: "uups",
  });

  const LaxceCrowdSaleAddress = await LaxceCrowdSale_.getAddress();

  console.log(
    `ESTIA Crowdsale Contract Address: ${LaxceCrowdSaleAddress}`
  );

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});