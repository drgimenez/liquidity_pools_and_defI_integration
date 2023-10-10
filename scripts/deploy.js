const { ethers } = require("hardhat");

async function main() {

    console.log("---------------------------------------------------------------------------------------");
    console.log("- Treasury contract deploy process started");
    console.log("---------------------------------------------------------------------------------------------");

    /// Get provider
    provider = ethers.provider;

    /// get signers
    [signer] = await ethers.getSigners();
    
    // Treasury contract deploy
    const treasury_contract_path = "src/contracts/Treasury.sol:Treasury";
    const Treasury_factory = await ethers.getContractFactory(treasury_contract_path, signer);
    const treasury_contract = await Treasury_factory.deploy();
    await provider.waitForTransaction(treasury_contract.deployTransaction.hash, 1);

    // AAVE_Adapter contract deploy
    const pool_address = "0xcC6114B983E4Ed2737E9BD3961c9924e6216c704"; // Pool proxy
    const AAVE_Adapter_contract_path = "src/contracts/adapters/AAVE_Adapter.sol:AAVE_Adapter";
    const AAVE_Adapter_factory = await ethers.getContractFactory(AAVE_Adapter_contract_path, signer);
    const AAVE_Adapter_contract = await AAVE_Adapter_factory.deploy(pool_address); 
    await provider.waitForTransaction(AAVE_Adapter_contract.deployTransaction.hash, 1);

    // Add treasury contract as owner of AAVE_Adapter contract
    const tx = await AAVE_Adapter_contract.addOwner(treasury_contract.address);
    await tx.wait();
    
    console.log("---------------------------------------------------------------------------------------");
    console.log("-- Contracts have been successfully deployed");
    console.log("---------------------------------------------------------------------------------------");
    console.log("-- Treasury contract address:\t\t", treasury_contract.address);
    console.log("-- AAVE_Adapter contract address:\t", AAVE_Adapter_contract.address);
    console.log("---------------------------------------------------------------------------------------");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });