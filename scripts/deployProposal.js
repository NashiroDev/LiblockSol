async function main() {
  const Proposal = await ethers.getContractFactory("Proposal");

  // Start deployment, returning a promise that resolves to a contract object
  const proposal = await Proposal.deploy('0xf2c06D8B5986eB79473CFfF70ABfc2E5986F4EB6');
  console.log("Contract deployed to address:", proposal.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });