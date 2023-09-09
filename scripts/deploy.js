async function main() {
  const Liblock = await ethers.getContractFactory("Liblock");

  // Start deployment, returning a promise that resolves to a contract object
  const liblock = await Liblock.deploy();   
  console.log("Contract deployed to address:", liblock.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });