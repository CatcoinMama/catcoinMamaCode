const deadWallet = '0x000000000000000000000000000000000000dEaD';

const forking = {
    url: 'https://speedy-nodes-nyc.moralis.io/a92cffb2a6b25abb39cf1072/bsc/mainnet/archive',
    blockNumber: 16043640,
}
const networkConfigs = {
    hardhat: {
        uniswapAddress: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
        catsAddress: '0x3B3691d4C3EC75660f203F41adC6296a494404d0',
        gasConfig: {
            gasLimit: 21000000,
            gasPrice: 7123000000,
        },
        privateSaleWallets: [
            '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65',
            '0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc',
        ],
    },
    testnet: {
        uniswapAddress: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3',
        catsAddress: '0xF9f93cF501BFaDB6494589Cb4b4C15dE49E85D0e',
        gasConfig: {
            gasLimit: 21000000,
            gasPrice: 10000000000,
        },
        privateSaleWallets: [
            '0x8255ae9bd8da1b41cb5734d79552ec59b4cc933b',
            '0xca799c4c04d8dac719ccc82352aba00ac9bfad00',
            '0xbf8c53fd6fa2006322254f45c34d83983b922f8c',
            '0x8a9a4b663bb0f423c9a5b759531cd62fb3a87cce',
            '0xab9a0d57c16aeCea26E1d4265357D0B599cA2565',
            '0x692e01c69050073a755554d9a6e6683c02591631',
            '0x1249eB120D03e37F1e6BD48FE7DEc7EfBE65fe31',
            '0x9ba304bb81dcfb7ffe256d5751daa517b6a7f443',
            '0x9fc1449c4407bde3ab698e3641f070c71992d8ae',
            '0xbdde127e44f9d7e5fbc6936f610a6c11b110e158',
            '0xba5cb8ba5d35fcef804eb1320ac9a296cd32bedb',
            '0x0b93dc80086c6d727c6f111ed20f6e9eee1d5235',
            '0x3595be4d9ae2906eb563652c3ba4818ebb17b0d1',
            '0x1797EC88024cE48c7E2e1580aBFcB2ADD0874019',
            '0x9ed37a02009d5ef91ad3b8361c5d39dec6f28324',
            '0xd676b495e0a18cf004df5706c73463de48509b34',
            '0xf57879bc2e44039993c6c298cc0c705e9bc02f6a',
            '0x46b4f3616db532b198fa5ca34398ecf1deb38912',
            '0xcd85b50156594eacfbd1e3e33169b7dfc36489bc',
            '0xCA1215E68694F582653daB3D4CF25f865bAA3f31',
        ],
    },
    production: {
        uniswapAddress: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
        catsAddress: '0x3B3691d4C3EC75660f203F41adC6296a494404d0',
        gasConfig: {
            gasLimit: 21000000,
            gasPrice: 7123000000,
        },
        privateSaleWallets: [
            '0x8255ae9bd8da1b41cb5734d79552ec59b4cc933b',
            '0xca799c4c04d8dac719ccc82352aba00ac9bfad00',
            '0xbf8c53fd6fa2006322254f45c34d83983b922f8c',
            '0x8a9a4b663bb0f423c9a5b759531cd62fb3a87cce',
            '0xab9a0d57c16aeCea26E1d4265357D0B599cA2565',
            '0x692e01c69050073a755554d9a6e6683c02591631',
            '0x1249eB120D03e37F1e6BD48FE7DEc7EfBE65fe31',
            '0x9ba304bb81dcfb7ffe256d5751daa517b6a7f443',
            '0x9fc1449c4407bde3ab698e3641f070c71992d8ae',
            '0xbdde127e44f9d7e5fbc6936f610a6c11b110e158',
            '0xba5cb8ba5d35fcef804eb1320ac9a296cd32bedb',
            '0x0b93dc80086c6d727c6f111ed20f6e9eee1d5235',
            '0x3595be4d9ae2906eb563652c3ba4818ebb17b0d1',
            '0x1797EC88024cE48c7E2e1580aBFcB2ADD0874019',
            '0x9ed37a02009d5ef91ad3b8361c5d39dec6f28324',
            '0xd676b495e0a18cf004df5706c73463de48509b34',
            '0xf57879bc2e44039993c6c298cc0c705e9bc02f6a',
            '0x46b4f3616db532b198fa5ca34398ecf1deb38912',
            '0xcd85b50156594eacfbd1e3e33169b7dfc36489bc',
            '0xCA1215E68694F582653daB3D4CF25f865bAA3f31',
        ],
    },
}
module.exports = {
    forking,
    networkConfigs,
    deadWallet,
}