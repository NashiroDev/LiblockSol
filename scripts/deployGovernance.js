async function main() {
  const pGovernance = await ethers.getContractFactory("Governance");

  // Start deployment, returning a promise that resolves to a contract object
  const governance = await pGovernance.deploy('0xd8bD9d1d5d3a3672348dF21Eb0541f7c920d4310');
  console.log("Contract deployed to address:", governance.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });