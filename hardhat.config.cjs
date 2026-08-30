require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    ethereum: {
      url: "https://ethereum.publicnode.com",
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};
