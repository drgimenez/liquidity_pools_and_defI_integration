const { ethers } = require("hardhat");
const chai = require("chai");
const { solidity } = require("ethereum-waffle");
chai.use(solidity);
const { expect } = chai;

const fs = require('fs');
const path = require('path');

const zeroAddress = '0x0000000000000000000000000000000000000000';

let tx, provider, MATIC_Account, USDC_Account, USDC_contract, treasury_contract;

describe("DERA Project test", () => {
    describe("Polygon Mainnet Network Fork", () => {
        before(async () => {

            console.log();
            console.log("---------------------------------------------------------------------------------------------");
            console.log("- Polygon Mainnet forked network");
            console.log("---------------------------------------------------------------------------------------------");
            
            // -------------------------------------------------------------------------------------------------------
            // Impersonate account with funds in Polygon Mainet
            // -------------------------------------------------------------------------------------------------------

            // USDC signers account address
            const MATIC_AccountAddress = "0x51bfacfce67821ec05d3c9bc9a8bc8300fb29564";
            const USDC_AccountAddress = "0x5a52e96bacdabb82fd05763e25335261b270efcb";

            // Impersonate accounts with MATIC and USDC
            MATIC_Account = await ethers.getImpersonatedSigner(MATIC_AccountAddress);
            USDC_Account = await ethers.getImpersonatedSigner(USDC_AccountAddress);

            // -------------------------------------------------------------------------------------------------------
            // Impersonate contracts in Polygon Mainet
            // -------------------------------------------------------------------------------------------------------

            // USDC contract address
            const USDC_contract_address = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

            // Impersonate USDC contract
            const USDC_ABIPath = path.resolve(process.cwd(), "artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json");
            const USDC_Artifact = JSON.parse(fs.readFileSync(USDC_ABIPath, 'utf8'));
            USDC_contract = await ethers.getContractAt(USDC_Artifact.abi, USDC_contract_address, MATIC_Account);
        });

        describe("Positive test", async () => {
            it("Check USDC balance for impersonated account", async () => {                
                const usdcBalance = await USDC_contract.balanceOf(USDC_Account.address);
                const usdcExpectedBalance = ethers.utils.parseEther("0.000020000015620609");
                expect(usdcBalance).to.be.equal(usdcExpectedBalance);
            });
        });
    });

    describe("Deploy contracts and impersonate accounts", () => {
        before(async () => {

            console.log("---------------------------------------------------------------------------------------------");
            console.log("- Treasury contract test");
            console.log("---------------------------------------------------------------------------------------------");

            // Treasury contract deploy
            const treasury_contract_path = "src/contracts/Treasury.sol:Treasury";
            const Treasury_factory = await ethers.getContractFactory(treasury_contract_path, MATIC_Account);
            treasury_contract = await Treasury_factory.deploy();
        });

        describe("Positive test", async () => {
            it("Check owner address", async () => {
                const isOwner = await treasury_contract.owner(MATIC_Account.address);    
                expect(isOwner).to.be.true;
            });
        });
    });

    describe("addToken method test", () => {
        before(async () => {
            const _name = "USDC";
            const _token = USDC_contract.address;
            tx = await treasury_contract.addCurrency(_name, _token);
            await tx.wait();
        });

        describe("Positive test", async () => {
            it("Check currency index 1 test", async () => {
                const _currency = await treasury_contract.currency(1);
                expect(_currency.isActive).to.be.true;
                expect(_currency.name).to.be.equals("USDC");
                expect(_currency.token).to.be.equals(USDC_contract.address);
            });
        });
    });

    describe("addProtocol method test", () => {
        const aave_protocolAddress = "0xD6DF932A45C0f255f85145f286eA0b292B21C90B";

        before(async () => {
            const _name = "AAVE";
            const _adapter = zeroAddress;
            const _percentage = 10;
            tx = await treasury_contract.addProtocol(_name, aave_protocolAddress, _adapter, _percentage);
            await tx.wait();
        });

        describe("Positive test", async () => {
            it("Check protocol index 1 test", async () => {
                const _protocolIndex = 1;
                const _percentage = 10;
                const _protocol = await treasury_contract.protocol(_protocolIndex);
                
                expect(_protocol.isActive).to.be.true;
                expect(_protocol.name).to.be.equals("AAVE");
                expect(_protocol.percentage).to.be.equals(_percentage);
                expect(_protocol.protocolAddress).to.be.equals(aave_protocolAddress);
                expect(_protocol.adapterAddress).to.be.equals(zeroAddress);
            });
        });
    });

    describe("updateProtocol method test", () => {
        const _protocolIndex = 1;
        const aave_protocolAddress = "0xD6DF932A45C0f255f85145f286eA0b292B21C90B";

        before(async () => {
            const _name = "AAVE";
            const _adapter = zeroAddress;
            const _percentage = 20;
            tx = await treasury_contract.updateProtocol(_protocolIndex, _name, aave_protocolAddress, _adapter, _percentage);
            await tx.wait();
        });

        describe("Positive test", async () => {
            it("Check protocol index 1 test porcentage change to 20", async () => {
                const _percentage = 20;
                const _protocol = await treasury_contract.protocol(_protocolIndex);
                
                expect(_protocol.isActive).to.be.true;
                expect(_protocol.name).to.be.equals("AAVE");
                expect(_protocol.percentage).to.be.equals(_percentage);
                expect(_protocol.protocolAddress).to.be.equals(aave_protocolAddress);
                expect(_protocol.adapterAddress).to.be.equals(zeroAddress);
            });
        });
    });

    describe("deposit method test", () => {
        const _amount = 10000000000;
        
        before(async () => {
            const _currencyIndex = 1;

            const USDC_contract2 = USDC_contract.connect(USDC_Account);
            tx = await USDC_contract2.approve(treasury_contract.address, _amount);
            await tx.wait();

            const treasury_contract2 = treasury_contract.connect(USDC_Account);
            tx = await treasury_contract2.deposit(_currencyIndex, _amount);
            await tx.wait();
        });

        describe("Positive test", async () => {
            it("Check USDC balance test", async () => {
                const _balance = await USDC_contract.balanceOf(treasury_contract.address);
                expect(_balance).to.be.equals(_amount);
            });

            it("Check deposit test", async () => {
                const _balance = await treasury_contract.balanceOf("USDC", USDC_Account.address);
                expect(_balance).to.be.equals(_amount);
            });
        });
    });
});