import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { BigNumber } from "@ethersproject/bignumber";
import { utils } from "ethers";
import { expect } from "chai";
import { ethers } from "hardhat";

function createCommit2(moveId: number, turn: number, battleId: BigNumber, salt: number) {
    return utils.solidityKeccak256(["uint8", "uint256", "uint256", "uint256"], [moveId, turn, battleId, salt]);
  }

describe("EtherMon", function () {
    describe("Enrollment", function () {
        it("Should enroll a new player", async function () {
            const EtherMon = await ethers.getContractFactory("EtherMon");
            const ethermon = await EtherMon.deploy();
            await ethermon.deployed();
            await ethermon.enroll(1);
            let pl = await ethermon.getPlayer();
            expect(pl.money).to.equal(1000);
            expect(pl.pokemons.length).to.equal(1);
            expect(pl.pokemons[0].level).to.equal(5);
            expect(pl.pokemons[0].id).to.equal(1);
            expect(pl.pokemons[0].hp).to.equal(45);
            expect(pl.pokemons[0].attack).to.equal(49);
            expect(pl.pokemons[0].defense).to.equal(49);
            expect(pl.pokemons[0].speed).to.equal(45);
        });
        
        it("Should not enroll a new player if already enrolled", async function () {
            const EtherMon = await ethers.getContractFactory("EtherMon");
            const ethermon = await EtherMon.deploy();
            await ethermon.deployed();
            await ethermon.enroll(1);
            await expect(ethermon.enroll(1)).to.be.revertedWith("Already enrolled");
        });
        
        it("Should not enroll if wrong choice of starter", async function () {
            const EtherMon = await ethers.getContractFactory("EtherMon");
            const ethermon = await EtherMon.deploy();
            await ethermon.deployed();
            await expect(ethermon.enroll(5)).to.be.revertedWith("Invalid starter choice");
        });
    });

    describe("Battles", function () {

        async function createScenario() {
            const EtherMon = await ethers.getContractFactory("EtherMon");
            const ethermon = await EtherMon.deploy();
            await ethermon.deployed();

            const [owner, otherAccount] = await ethers.getSigners();
            
            await ethermon.connect(owner).enroll(1);
            let p1 = await ethermon.connect(owner).getPlayer();
            await ethermon.connect(otherAccount).enroll(2);
            let p2 = await ethermon.connect(otherAccount).getPlayer();
            return {ethermon, p1, p2, key1: owner, key2: otherAccount};
        }

        it("Should start a battle", async function () {
            const {ethermon, p1, p2, key1, key2} = await createScenario();

            let transaction = await ethermon.connect(key1).challenge(p2.addr, 69);
            let battleId = transaction.value;
            expect(battleId).to.equal(0);
            let battle = await ethermon.getBattle(battleId);
            expect(battle.players[0]).to.equal(p1.addr);
            expect(battle.players[1]).to.equal(p2.addr);
            expect(battle.wager).to.equal(69);
            expect(battle.status).to.equal(0);
            let p1_updated = await ethermon.connect(key1).getPlayer();
            expect(p1_updated.money).to.equal(1000 - 69);
            let p2_updated = await ethermon.connect(key2).getPlayer();
            expect(p2_updated.money).to.equal(1000);

            await ethermon.connect(key2).acceptChallenge(battleId);
            battle = await ethermon.getBattle(battleId);
            expect(battle.status).to.equal(2);
            p1_updated = await ethermon.connect(key1).getPlayer();
            expect(p1_updated.money).to.equal(1000 - 69);
            p2_updated = await ethermon.connect(key2).getPlayer();
            expect(p2_updated.money).to.equal(1000 - 69);
        });

        it("Should not start a battle", async function () {
            const {ethermon, p1, p2, key1, key2} = await createScenario();

            let transaction = await ethermon.connect(key1).challenge(p2.addr, 69);
            let battleId = transaction.value;
            expect(battleId).to.equal(0);
            let battle = await ethermon.getBattle(battleId);
            expect(battle.players[0]).to.equal(p1.addr);
            expect(battle.players[1]).to.equal(p2.addr);
            expect(battle.wager).to.equal(69);
            expect(battle.status).to.equal(0);
            let p1_updated = await ethermon.connect(key1).getPlayer();
            expect(p1_updated.money).to.equal(1000 - 69);
            let p2_updated = await ethermon.connect(key2).getPlayer();
            expect(p2_updated.money).to.equal(1000);

            await ethermon.connect(key2).rejectChallenge(battleId);
            battle = await ethermon.getBattle(battleId);
            expect(battle.status).to.equal(1);
            p1_updated = await ethermon.connect(key1).getPlayer();
            expect(p1_updated.money).to.equal(1000);
            p2_updated = await ethermon.connect(key2).getPlayer();
            expect(p2_updated.money).to.equal(1000);
        });

        // todo: add test for commitment thingy
        it("should damage the pokemons", async function () {
            const {ethermon, p1, p2, key1, key2} = await createScenario();

            let transaction = await ethermon.connect(key1).challenge(p2.addr, 69);
            let battleId = transaction.value;
            let battle = await ethermon.getBattle(battleId);
            let p1_updated = await ethermon.connect(key1).getPlayer();
            let p2_updated = await ethermon.connect(key2).getPlayer();

            await ethermon.connect(key2).acceptChallenge(battleId);
            battle = await ethermon.getBattle(battleId);
            p1_updated = await ethermon.connect(key1).getPlayer();
            p2_updated = await ethermon.connect(key2).getPlayer();

            let p1_pokemon = await ethermon.connect(key1).getBattlePokemon(battleId);
            let p2_pokemon = await ethermon.connect(key2).getBattlePokemon(battleId);
            expect(p1_pokemon.hp).to.equal(45);
            expect(p2_pokemon.hp).to.equal(39);
            expect(battle.status).to.equal(2);

            for(let turn = 0; turn < 3; ++turn) {
                let comm1 = createCommit2(100, turn, battleId, 1234);
                await ethermon.connect(key1).submitMoveCommitment(comm1, battleId);
                battle = await ethermon.getBattle(battleId);
                expect(battle.commitments[0]).to.equal(comm1);
                expect(battle.turn).to.equal(4*turn + 1);
                expect(battle.status).to.equal(2);
                
                let comm2 = createCommit2(100, turn, battleId, 5678);
                await ethermon.connect(key2).submitMoveCommitment(comm2, battleId);
                battle = await ethermon.getBattle(battleId);
                expect(battle.commitments[1]).to.equal(comm2);
                expect(battle.turn).to.equal(4*turn + 2);
                expect(battle.status).to.equal(3);
                
                await ethermon.connect(key1).submitMoveDecommitment(100, battleId, 1234);
                battle = await ethermon.getBattle(battleId);
                expect(battle.turn).to.equal(4*turn + 3);
                expect(battle.status).to.equal(3);
    
                await ethermon.connect(key2).submitMoveDecommitment(100, battleId, 5678);
                battle = await ethermon.getBattle(battleId);
                expect(battle.turn).to.equal(4*turn + 4);
                expect(battle.status).to.equal(2);
    
                p1_pokemon = await ethermon.connect(key1).getBattlePokemon(battleId);
                p2_pokemon = await ethermon.connect(key2).getBattlePokemon(battleId);
                expect(p1_pokemon.hp).to.equal(45 - (turn + 1) * 10);
                expect(p2_pokemon.hp).to.equal(39 - (turn + 1) * 11);
            }

            let turn = 3;
            let comm1 = createCommit2(100, turn, battleId, 1234);
            await ethermon.connect(key1).submitMoveCommitment(comm1, battleId);
            battle = await ethermon.getBattle(battleId);
            expect(battle.commitments[0]).to.equal(comm1);
            expect(battle.turn).to.equal(4*turn + 1);
            expect(battle.status).to.equal(2);
            
            let comm2 = createCommit2(100, turn, battleId, 5678);
            await ethermon.connect(key2).submitMoveCommitment(comm2, battleId);
            battle = await ethermon.getBattle(battleId);
            expect(battle.commitments[1]).to.equal(comm2);
            expect(battle.turn).to.equal(4*turn + 2);
            expect(battle.status).to.equal(3);
            
            await ethermon.connect(key1).submitMoveDecommitment(100, battleId, 1234);
            battle = await ethermon.getBattle(battleId);
            expect(battle.turn).to.equal(4*turn + 3);
            expect(battle.status).to.equal(3);

            await ethermon.connect(key2).submitMoveDecommitment(100, battleId, 5678);
            battle = await ethermon.getBattle(battleId);
            expect(battle.turn).to.equal(4*turn + 4);
            
            p1_pokemon = await ethermon.connect(key1).getBattlePokemon(battleId);
            p2_pokemon = await ethermon.connect(key2).getBattlePokemon(battleId);
            expect(p1_pokemon.hp).to.equal(45 - (turn + 1) * 10);
            expect(p2_pokemon.hp).to.equal(0);
            expect(battle.status).to.equal(4);

            p1_updated = await ethermon.connect(key1).getPlayer();
            p2_updated = await ethermon.connect(key2).getPlayer();

            expect(p1_updated.money).to.equal(1000 + 69);
            expect(p2_updated.money).to.equal(1000 - 69);
            expect(p1_updated.pokemons[0].exp).to.equal(10);
            
        });
    });
});
