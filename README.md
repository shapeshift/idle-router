# ShapeShift DAOs Affiliate Router for Idle Finance

This router provides a thin wrapper around the IdleFinance CDO contract suite to allow for 
tracking of deposits that originate from Shapeshift users for the IdleCDO contracts. 

# Idle Finance Documentation and Contracts

- [IdleFinance Docs](https://docs.idle.finance/developers/perpetual-yield-tranches)
- [IdleCdo.sol](https://github.com/Idle-Labs/idle-tranches/blob/master/contracts/IdleCDO.sol)
- [Deployed Addresses](https://docs.idle.finance/developers/contracts-and-codebase/ethereum-mainnet#perpetual-yield-tranches-strategy)

# Getting Started

The test suite uses a forked mainnet environment to test against the IdleCdo contracts. To run 
the test suite you must provide a ethereum node to interact with in the .env file.  A free node / api key
can be obtained from infura or alchemy.

#### To run the tests 
1. `yarn install`
1. copy the .env.example over to .env and add needed variables
1. `yarn test`
