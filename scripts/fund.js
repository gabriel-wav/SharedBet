const hre = require("hardhat");

async function main() {
  // Pegar contas do Hardhat
  const accounts = await hre.ethers.getSigners();
  const deployer = accounts[0];
  
  console.log("Deployer address:", deployer.address);
  const deployerBalance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Deployer balance:", hre.ethers.formatEther(deployerBalance), "ETH");

  // Quantidade de ETH para enviar (100 ETH)
  const amount = hre.ethers.parseEther("100");

  // Verificar se foi passado um endereço como argumento
  const targetAddress = process.argv[2];
  
  if (!targetAddress) {
    console.error("\n❌ Erro: Por favor, forneça um endereço!");
    console.log("\nUso:");
    console.log("  node scripts/fund.js 0xSEU_ENDERECO_DO_METAMASK");
    console.log("\nOu usando npm:");
    console.log("  npm run fund -- 0xSEU_ENDERECO_DO_METAMASK");
    process.exit(1);
  }

  // Validar formato do endereço
  if (!hre.ethers.isAddress(targetAddress)) {
    console.error(`\n❌ Erro: "${targetAddress}" não é um endereço válido!`);
    process.exit(1);
  }

  console.log(`\n📤 Enviando 100 ETH para: ${targetAddress}`);
  
  try {
    const tx = await deployer.sendTransaction({
      to: targetAddress,
      value: amount,
    });
    console.log(`⏳ Transação enviada. Aguardando confirmação...`);
    console.log(`   Tx hash: ${tx.hash}`);
    
    const receipt = await tx.wait();
    console.log(`\n✅ Sucesso! 100 ETH enviados para ${targetAddress}`);
    console.log(`   Block: ${receipt.blockNumber}`);
    console.log(`   Gas usado: ${receipt.gasUsed.toString()}`);
    
    // Mostrar novo saldo (opcional, pode falhar se o endereço não for uma conta do Hardhat)
    try {
      const newBalance = await hre.ethers.provider.getBalance(targetAddress);
      console.log(`   Novo saldo: ${hre.ethers.formatEther(newBalance)} ETH`);
    } catch (e) {
      // Ignorar erro se não conseguir ler o saldo
    }
  } catch (error) {
    console.error(`\n❌ Erro ao enviar ETH:`, error.message);
    if (error.code === 'INSUFFICIENT_FUNDS') {
      console.error("   O deployer não tem ETH suficiente!");
    }
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

