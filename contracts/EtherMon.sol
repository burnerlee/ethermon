// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "./Pokedex.sol";

struct Player {
    address addr;
    Pokemon[] pokemons;
    uint256 money;
    uint256[] battles;
}

enum BattleState {
    PENDING,
    REJECTED,
    WAITING_FOR_COMMITMENTS,
    WAITING_FOR_DECOMMITMENTS,
    FINISHED
}

struct Battle {
    uint256 wager;
    BattleState status;
    uint256 turn;
    address[2] players;
    bytes32[2] commitments;
    uint32[2]  moves;
    // Pokemon[2]  pokemons;
}

contract EtherMon {
    mapping(address => Player) public players;
    mapping(bytes32 => Pokemon) public battlePokemon;
    Battle[] public battles;

    function enroll(uint starterChoice) public {
        require(players[msg.sender].addr == address(0), "Already enrolled");
        players[msg.sender].addr = msg.sender;
        players[msg.sender].money = 1000;
        require(starterChoice >= 1 && starterChoice <= 3, "Invalid starter choice");
        uint id = starterChoice * 3 - 2;
        players[msg.sender].pokemons.push(
            Pokemon(id, 5, 0, uint8(baseHp[id-1]), uint8(baseAttack[id-1]), uint8(baseDefense[id-1]), uint8(baseSpeed[id-1]))
        );
    }

    function getPlayer() public view returns (Player memory) {
        return players[msg.sender];
    }

    function challenge(address opponent, uint256 wager) public returns (uint256) {
        require(players[msg.sender].addr != address(0), "Not enrolled");
        require(players[opponent].addr != address(0), "Opponent not enrolled");
        require(players[msg.sender].pokemons.length > 0, "No pokemon");
        require(players[opponent].pokemons.length > 0, "Opponent has no pokemon");
        require(players[msg.sender].money >= wager, "Not enough money");
        require(players[opponent].money >= wager, "Opponent doesn't have enough money");

        players[msg.sender].money -= wager;
        uint256 battleId = battles.length;
        battles.push(
            Battle(
                wager, 
                BattleState.PENDING, 
                0, 
                [ msg.sender, opponent ], 
                [bytes32(0), bytes32(0)], 
                [uint32(0), uint32(0)]
                // [ players[msg.sender].pokemons[0], players[opponent].pokemons[0] ]
            )
        );
        battlePokemon[keccak256(abi.encodePacked(battleId, uint8(0)))] = players[msg.sender].pokemons[0];
        battlePokemon[keccak256(abi.encodePacked(battleId, uint8(1)))] = players[opponent].pokemons[0];
        
        players[msg.sender].battles.push(battleId);
        players[opponent].battles.push(battleId);
        return battleId;
    }

    function acceptChallenge(uint256 battleId) public {
        require(battles[battleId].status == BattleState.PENDING, "Battle not pending");
        require(battles[battleId].players[1] == msg.sender, "Not your battle");
        battles[battleId].status = BattleState.WAITING_FOR_COMMITMENTS;
        players[msg.sender].money -= battles[battleId].wager;
    }

    function rejectChallenge(uint256 battleId) public {
        require(battles[battleId].status == BattleState.PENDING, "Battle not pending");
        require(battles[battleId].players[1] == msg.sender, "Not your battle");
        battles[battleId].status = BattleState.REJECTED;
        players[battles[battleId].players[0]].money += battles[battleId].wager;
    }

    function getBattle(uint256 battleId) public view returns (Battle memory) {
        return battles[battleId];
    }

    function getMyBattles() public view returns (uint256[] memory) {
        return players[msg.sender].battles;
    }

    function submitMoveCommitment(bytes32 commitment, uint256 battleId) public {
        require(battles[battleId].status == BattleState.WAITING_FOR_COMMITMENTS, "Battle not waiting for commitments");
        require(battles[battleId].players[0] == msg.sender || battles[battleId].players[1] == msg.sender, "Not your battle");
        require(battles[battleId].turn % 4 == 0 || battles[battleId].turn % 4 == 1, "Invalid state, abandon this battle!");
        // console.log(battleId);

        if (battles[battleId].players[0] == msg.sender) {
            battles[battleId].commitments[0] = commitment;
        } else {
            battles[battleId].commitments[1] = commitment;
        }
        battles[battleId].turn += 1;
        if (battles[battleId].turn % 4 == 2) {
            battles[battleId].status = BattleState.WAITING_FOR_DECOMMITMENTS;
        }
    }

    function submitMoveDecommitment(uint8 moveId, uint256 battleId, uint256 salt) public {
        require(battles[battleId].status == BattleState.WAITING_FOR_DECOMMITMENTS, "Battle not waiting for decommitments");
        require(battles[battleId].players[0] == msg.sender || battles[battleId].players[1] == msg.sender, "Not your battle");
        require(battles[battleId].turn % 4 == 2 || battles[battleId].turn % 4 == 3, "Invalid state, abandon this battle!");

        bytes32 commitment;
        if (battles[battleId].players[0] == msg.sender) {
            commitment = battles[battleId].commitments[0];
        } else {
            commitment = battles[battleId].commitments[1];
        }
        bytes32 expected = keccak256(abi.encodePacked(moveId, battles[battleId].turn/4, battleId, salt));
        require(expected == commitment, "Invalid commitment");

        if (battles[battleId].players[0] == msg.sender) {
            battles[battleId].moves[0] = moveId;
        } else {
            battles[battleId].moves[1] = moveId;
        }
        battles[battleId].turn += 1;

        if (battles[battleId].turn % 4 == 0) {
            // evaluate move
            evaluateMove(battleId);
            if (battles[battleId].status != BattleState.FINISHED) {
                battles[battleId].status = BattleState.WAITING_FOR_COMMITMENTS;
            }
            battles[battleId].commitments[0] = bytes32(0);
            battles[battleId].commitments[1] = bytes32(0);
            battles[battleId].moves[0] = 0;
            battles[battleId].moves[1] = 0;
        }
    }

    function affectMove(uint256 battleId, uint8 mover) private {
        // todo
        Battle memory battle = battles[battleId];
        uint32 move = battle.moves[mover];
        if (move < 6) {
            // todo: pokemon switch
        }
        else if (move == 7){
            // pootion
            bytes32 pokeAddr = keccak256(abi.encodePacked(battleId, mover));
            Pokemon memory pokemon = battlePokemon[pokeAddr];
            pokemon.hp = pokemon.hp + 20;
            battlePokemon[pokeAddr] = pokemon;
        }
        else if (move == 100) {
            // tackle
            bytes32 pokeAddr1 = keccak256(abi.encodePacked(battleId, mover));
            bytes32 pokeAddr2 = keccak256(abi.encodePacked(battleId, 1-mover));
            Pokemon memory challenger = battlePokemon[pokeAddr1];
            Pokemon memory opponent = battlePokemon[pokeAddr2];
            uint16 damage = 10;
            damage = damage * challenger.attack;
            damage = damage / opponent.defense;
            if (opponent.hp < damage) {
                opponent.hp = 0;
            }
            else {
                opponent.hp = opponent.hp - uint8(damage);
            }
            battlePokemon[pokeAddr2] = opponent;
        }
    }

    function getBattlePokemon(uint256 battleId) public view returns(Pokemon memory) {
        Battle memory battle = battles[battleId];
        bool isChallenger = battle.players[0] == msg.sender;
        bool isOpponent = battle.players[1] == msg.sender;
        require(isChallenger || isOpponent, "Not your battle");
        if (isChallenger) {
            return battlePokemon[keccak256(abi.encodePacked(battleId, uint8(0)))];
        }
        else {
            return battlePokemon[keccak256(abi.encodePacked(battleId, uint8(1)))];
        }
    }

    function normalizeExp(address p) private {
        Pokemon memory pokemon = players[p].pokemons[0];
        uint exp   = pokemon.exp;
        uint level = pokemon.level;
        if (exp >= 100) {
            players[p].pokemons[0].exp = exp - 100;
            players[p].pokemons[0].level = level + 1;
            players[p].pokemons[0].hp += 5;
            players[p].pokemons[0].attack += 5;
            players[p].pokemons[0].defense += 5;
            players[p].pokemons[0].speed += 5;
        }
    }

    function evaluateMove(uint256 battleId) private {
        Battle memory battle = battles[battleId];

        uint32 move1 = battle.moves[0];
        uint32 move2 = battle.moves[1];
        bytes32 pokeaddr1 = keccak256(abi.encodePacked(battleId, uint8(0)));
        bytes32 pokeaddr2 = keccak256(abi.encodePacked(battleId, uint8(1)));

        // first 100 moves are item usage or pokemon switch
        if (move1 < 100 && move2 < 100) {
            // both players using an item, order doesn't matter
            affectMove(battleId, 0);
            affectMove(battleId, 1);
        }
        else if (move1 < 100) {
            // player 1 using an item, player 2 using a move
            affectMove(battleId, 0);
            affectMove(battleId, 1);
            if (battlePokemon[pokeaddr1].hp == 0) {
                // player 1's pokemon fainted, player 1 wins
                battles[battleId].status = BattleState.FINISHED;
                players[battle.players[1]].money += 2 * battle.wager;
                players[battle.players[1]].pokemons[0].exp += 10;
                normalizeExp(battle.players[1]);
            }
        }
        else if (move2 < 100) {
            // player 2 using an item, player 1 using a move
            affectMove(battleId, 1);
            affectMove(battleId, 0);
            if (battlePokemon[pokeaddr2].hp == 0) {
                // player 2's pokemon fainted, player 2 wins
                battles[battleId].status = BattleState.FINISHED;
                players[battle.players[0]].money += 2 * battle.wager;
                players[battle.players[0]].pokemons[0].exp += 10;
                normalizeExp(battle.players[0]);
            }
        }
        else {
            // both players using a move
            Pokemon memory pokemon1 = battlePokemon[pokeaddr1];
            Pokemon memory pokemon2 = battlePokemon[pokeaddr2];
            if (pokemon1.speed >= pokemon2.speed) {
                affectMove(battleId, 0);
                if (battlePokemon[pokeaddr2].hp == 0) {
                    // player 2's pokemon fainted, player 1 wins
                    battles[battleId].status = BattleState.FINISHED;
                    players[battle.players[0]].money += 2 * battle.wager;
                    players[battle.players[0]].pokemons[0].exp += 10;
                    normalizeExp(battle.players[0]);
                }
                else {
                    affectMove(battleId, 1);
                    if (battlePokemon[pokeaddr1].hp == 0) {
                        // player 1's pokemon fainted, player 2 wins
                        battles[battleId].status = BattleState.FINISHED;
                        players[battle.players[1]].money += 2 * battle.wager;
                        players[battle.players[1]].pokemons[0].exp += 10;
                        normalizeExp(battle.players[1]);
                    }
                }
            } else {
                affectMove(battleId, 1);
                if (battlePokemon[pokeaddr1].hp == 0) {
                    // player 1's pokemon fainted, player 2 wins
                    battles[battleId].status = BattleState.FINISHED;
                    players[battle.players[1]].money += 2 * battle.wager;
                    players[battle.players[1]].pokemons[0].exp += 10;
                    normalizeExp(battle.players[1]);
                }
                else {
                    affectMove(battleId, 0);
                    if (battlePokemon[pokeaddr2].hp == 0) {
                        // player 2's pokemon fainted, player 1 wins
                        battles[battleId].status = BattleState.FINISHED;
                        players[battle.players[0]].money += 2 * battle.wager;
                        players[battle.players[0]].pokemons[0].exp += 10;
                        normalizeExp(battle.players[0]);
                    }
                }
            }
        }
    }
}
