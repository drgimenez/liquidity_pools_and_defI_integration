const { ethers } = require("hardhat");
const chai = require("chai");
const { solidity } = require("ethereum-waffle");
chai.use(solidity);
const { expect } = chai;

const fs = require('fs');
const path = require('path');

const zeroAddress = '0x0000000000000000000000000000000000000000';

let tx, provider, MATIC_Account, USDC_Account, USDC_contract, treasury_contract, AAVE_Adapter_contract, AAVE_aUSDC_contract;

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

            // AAVE_Adapter contract deploy
            const pool_address = "0x794a61358D6845594F94dc1DB02A252b5b4814aD";
            const AAVE_Adapter_contract_path = "src/contracts/adapters/AAVE_Adapter.sol:AAVE_Adapter";
            const AAVE_Adapter_factory = await ethers.getContractFactory(AAVE_Adapter_contract_path, MATIC_Account);
            AAVE_Adapter_contract = await AAVE_Adapter_factory.deploy(pool_address);

            // Impersonate AAVE Pool contract
            const AAVE_aUSDC_contractAddress = "0x625E7708f30cA75bfd92586e17077590C60eb4cD";
            const erc20_ABIPath = path.resolve(process.cwd(), "artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json");
            const erc20_Artifact = JSON.parse(fs.readFileSync(erc20_ABIPath, 'utf8'));
            AAVE_aUSDC_contract = await ethers.getContractAt(erc20_Artifact.abi, AAVE_aUSDC_contractAddress, MATIC_Account);
        });

        describe("Positive test", async () => {
            it("Check owner address on Treasury contract", async () => {
                const isOwner = await treasury_contract.owner(MATIC_Account.address);    
                expect(isOwner).to.be.true;
            });

            it("Check owner address on AAVE_Adapter contract", async () => {
                const isOwner = await AAVE_Adapter_contract.owner(MATIC_Account.address);    
                expect(isOwner).to.be.true;
            });

            it("Check pool address on AAVE_Adapter contract", async () => {
                const pool_address = "0x794a61358D6845594F94dc1DB02A252b5b4814aD";
                const pool_addressReceived = await AAVE_Adapter_contract.pool();    
                expect(pool_addressReceived).to.be.equals(pool_address);
            });

            it("AddOwner to AAVE_Adapter contract", async () => {
                tx = await AAVE_Adapter_contract.addOwner(treasury_contract.address);
                await tx.wait();

                const isOwner = await AAVE_Adapter_contract.owner(treasury_contract.address);
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
            const _adapter = AAVE_Adapter_contract.address;
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
                expect(_protocol.adapterAddress).to.be.equals(AAVE_Adapter_contract.address);
            });
        });
    });

    describe("updateProtocol method test", () => {
        const _protocolIndex = 1;
        const aave_protocolAddress = "0xD6DF932A45C0f255f85145f286eA0b292B21C90B";

        before(async () => {
            const _name = "AAVE";
            const _adapter = AAVE_Adapter_contract.address;
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
                expect(_protocol.adapterAddress).to.be.equals(AAVE_Adapter_contract.address);
            });
        });
    });

    describe("invest method test", async () => {
        const _protocolIndex = 1;
        const _currencyIndex = 1;
        let _amount = ethers.utils.parseUnits("10000", 6);
        let _balanceBefore, _amountToInvest;
        
        before(async () => {
            const _percentage = (await treasury_contract.protocol(_protocolIndex)).percentage;
            _amountToInvest = _amount.mul(_percentage).div(100);
            _balanceBefore = await USDC_contract.balanceOf(USDC_Account.address);
            
            const USDC_contract2 = USDC_contract.connect(USDC_Account);
            tx = await USDC_contract2.approve(treasury_contract.address, _amount);
            await tx.wait();

            const treasury_contract2 = treasury_contract.connect(USDC_Account);
            tx = await treasury_contract2.invest(_currencyIndex, _amount);
            await tx.wait();
        });

        describe("Positive test", async () => {
            it("Check USDC balance test", async () => {
                const _balanceAfter = await USDC_contract.balanceOf(USDC_Account.address);
                expect(_balanceAfter).to.be.equals(_balanceBefore.sub(_amount));
            });

            it("Check investOf test", async () => {
                const _investOf = await treasury_contract.investOf("AAVE", USDC_Account.address);
                expect(_investOf).to.be.equals(_amountToInvest);
            });
            
            it("Check aUSDC balance test", async () => {
                const _balance = await AAVE_aUSDC_contract.balanceOf(AAVE_Adapter_contract.address);
                expect(_balance).to.be.equals(_amountToInvest);
            });
        });
    });

    describe("calculateAggregatedPercentageYield method test", async () => {
        it("Call getReserveData", async () => {
            const _expectedValue = ethers.utils.parseEther("15.055971660622169600");
            const _currencyIndex = 1;
            const treasury_contract2 = treasury_contract.connect(USDC_Account);
            const _aggregatedPercentageYield = await treasury_contract2.calculateAggregatedPercentageYield(_currencyIndex);
            expect(_aggregatedPercentageYield).to.be.equals(_expectedValue);
        });
    });

    describe("withdraw method test", async () => {
        const _protocolIndex = 1;
        const _currencyIndex = 1;
        let _USDC_balanceBefore, _aUSDC_balanceBefore, _percentage, _amountToWithdraw;
        
        before(async () => {
            const _amount = ethers.utils.parseUnits("10000", 6);
            _percentage = (await treasury_contract.protocol(_protocolIndex)).percentage;
            _amountToWithdraw = _amount.mul(_percentage).div(100);
            _USDC_balanceBefore = await USDC_contract.balanceOf(USDC_Account.address);
            _aUSDC_balanceBefore = await AAVE_aUSDC_contract.balanceOf(AAVE_Adapter_contract.address);

            const treasury_contract2 = treasury_contract.connect(USDC_Account);
            tx = await treasury_contract2.withdraw(_protocolIndex, _currencyIndex, _amountToWithdraw);
            await tx.wait();
        });

        describe("Positive test", async () => {
            it("Check USDC balance test", async () => {
                const _USDC_balanceAfter = await USDC_contract.balanceOf(USDC_Account.address);
                expect(_USDC_balanceAfter).to.be.equals(_USDC_balanceBefore.add(_amountToWithdraw));
            });

            it("Check investOf test", async () => {
                const _investOf = await treasury_contract.investOf("AAVE", USDC_Account.address);
                expect(_investOf).to.be.equals(0);
            });
            
            it("Check aUSDC balance test", async () => {            
                const _aUSDC_balanceAfter = await AAVE_aUSDC_contract.balanceOf(treasury_contract.address);
                expect(_aUSDC_balanceAfter).to.be.equals(_aUSDC_balanceBefore.sub(_amountToWithdraw));
            });
        });
    });
});