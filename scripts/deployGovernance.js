async function main() {
  const gProposal = await ethers.getContractFactory("gProposal");

  // Start deployment, returning a promise that resolves to a contract object
  const proposal = await gProposal.deploy('LIB', 'rLIB');
  console.log("Contract deployed to address:", proposal.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });