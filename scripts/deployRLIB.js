async function main() {
    const rLiblock = await ethers.getContractFactory("rLiblock");
  
    // Start deployment, returning a promise that resolves to a contract object
    const rLIB = await rLiblock.deploy();
    console.log("Contract deployed to address:", rLIB.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });