import { HardhatUserConfig } from 'hardhat/config'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-ganache'

const GAS_LIMIT = 10000000

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      gas: GAS_LIMIT,
      blockGasLimit: GAS_LIMIT,
    },
    localhost: {
      url: "http://127.0.0.1:18545"
    },
    ganache: {
      // Workaround for https://github.com/nomiclabs/hardhat/issues/518
      url: 'http://127.0.0.1:8555',
      gasLimit: GAS_LIMIT,
    } as any,
    ropsten: {
      url: process.env.ETHEREUM_JSONRPC_HTTP_URL || 'http://127.0.0.1:8545',
      accounts: { mnemonic: '' },
    },
  },
  paths: {
    artifacts: "build/contracts",
    tests: "tests"
  },
  solidity: {
    version: "0.7.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20,
      },
    },
  },
};

export default config