import { ethers } from "hardhat";

async function main() {
    const RadioTips = await ethers.getContractFactory("RadioTips")
    const radioTips = await RadioTips.deploy()
    console.log("RadioTips deployed at:", radioTips.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });