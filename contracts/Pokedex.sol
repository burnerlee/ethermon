// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

struct Pokemon {
    uint id;
    uint level;
    uint exp;
    uint8 hp;
    uint8 attack;
    uint8 defense;
    uint8 speed;
}

// hex encoded base hp of all pokemons
bytes constant baseHp = hex"2d3c50273a4e2c3b4f";
// hex encoded base attack of all pokemons
bytes constant baseAttack = hex"313e52344054303f53";
// hex encoded base defense of all pokemons
bytes constant baseDefense = hex"313f532b3a4e415064";
// hex encoded base speed of all pokemons
bytes constant baseSpeed = hex"2d3c504150642b3a4e";
