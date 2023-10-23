const { run } = require("hardhat");
const fs = require('fs');
const path = require('path');

// npx hardhat run --network scrollSepolia scripts/verifyAll.js

async function verifyContract(contractAddress, args) {
    console.log(`\nVerifying contract at address: ${contractAddress}`);
    try {
        if (args.length === 1 && args[0] === '') {
            await run(`verify:verify`, {
                address: contractAddress,
            });
        } else {
            await run(`verify:verify`, {
                address: contractAddress,
                constructorArguments: [...args],
            });
        }
        return true;
    } catch (error) {
        console.error(`Error occurred while verifying contract: ${error}`);
        return false;
    }
}

function readContractAddressesFromCsv() {
    const csvFilePath = path.join(__dirname, '../reports/report.csv');
    const csvContent = fs.readFileSync(csvFilePath, 'utf8');
    const lines = csvContent.split('\n');
    const contractData = {};

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line === '- * - * -') {
            break;
        }
        const [contractName, contractAddresses] = line.split(':');
        const addresses = contractAddresses.split(',');
        contractData[contractName.trim()] = addresses.map(address => address.trim());
    }

    return contractData;
}

async function main() {
    const contractData = readContractAddressesFromCsv();
    const verificationResults = {};

    for (const contractName in contractData) {
        const contractAddresses = contractData[contractName];
        const isVerified = await verifyContract(contractAddresses[0], contractAddresses.slice(1));

        verificationResults[contractName] = isVerified;
    }

    writeVerificationResultsToCsv(verificationResults);
}

function writeVerificationResultsToCsv(verificationResults) {
    const csvFilePath = path.join(__dirname, '../reports/report.csv');
    let csvContent = '';

    for (const contractName in verificationResults) {
        const isVerified = verificationResults[contractName];
        csvContent += `${contractName}: ${isVerified ? 'Verified' : 'Not Verified'}\n`;
    }

    fs.appendFileSync(csvFilePath, csvContent);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });