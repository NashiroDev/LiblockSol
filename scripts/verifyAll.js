const { run } = require("hardhat");
const fs = require('fs');
const path = require('path');

async function verifyContract(contractAddress, args = []) {
    console.log(`Verifying contract at address: ${contractAddress}`);
    try {
        await run(`verify:verify`, {
            address: contractAddress,
            constructorArguments: args,
        });
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
        const [contractName, contractAddress] = line.split(':');
        contractData[contractName.trim()] = contractAddress.trim();
    }

    return contractData;
}

async function main() {
    const contractData = readContractAddressesFromCsv();
    const verificationResults = {};

    for (const contractName in contractData) {
        const contractAddress = contractData[contractName];
        const args = contractAddress.split('\n').map(address => address.trim());
        const isVerified = await verifyContract(contractAddress, args);

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