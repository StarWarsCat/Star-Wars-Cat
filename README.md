# contract project

### install nodejs
[Node.js](https://nodejs.org/en/)


## using with hardhat

### install hardhat (unnecessary)
[Hardhat | Ethereum development environment for professionals by Nomic Labs](https://hardhat.org/)
```shell script
$ npm install --save-dev hardhat
$ npx hardhat
```

### install hardhat-upgrades plugin (unnecessary)
[Hardhat | Ethereum development environment for professionals by Nomic Labs](https://hardhat.org/)
```shell script
$ npm install --save-dev @openzeppelin/hardhat-upgrades
```

### edit hardhat.config.js adding follow
```js
// hardhat upgrade plugins
require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');
```

### install pkg
```shell script
$ npm install
```

### edit config
`hardhat.config.js`  
`.env.js`  
`.secret.js`
