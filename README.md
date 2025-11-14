# 🌾 Fractional Farmland Investment Platform

A decentralized platform built on Stacks blockchain that enables fractional ownership of farmland investments. Pool funds with other investors to buy and manage farmland assets while earning yield tokens from agricultural profits.

## 🚀 Features

- **🌱 Pool Creation**: Create farmland investment pools with target funding goals
- **💰 Fractional Investment**: Invest any amount to get proportional shares  
- **🎯 Yield Distribution**: Automatic yield token distribution based on ownership
- **📊 Share Tracking**: Track your investments across multiple farmland pools
- **💵 Flexible Withdrawals**: Withdraw investments with proportional share calculation
- **🔒 Secure Management**: Pool owners can distribute yields and manage pools

## 🛠️ Contract Functions

### Read Functions

- `get-pool(pool-id)` - Get pool details by ID
- `get-investor-shares(pool-id, investor)` - Get investor's shares in a pool  
- `get-yield-tokens(investor)` - Check yield token balance
- `get-pool-count()` - Get total number of pools created
- `get-total-yield-distributed()` - Get total yield distributed across all pools

### Write Functions

- `create-farmland-pool(location, target-amount, yield-rate)` - Create new farmland pool
- `invest-in-pool(pool-id, amount)` - Invest STX in a farmland pool
- `distribute-yield(pool-id, total-yield)` - Distribute yield to investors (pool owner only)
- `claim-yield-tokens()` - Claim your accumulated yield tokens as STX
- `withdraw-investment(pool-id, amount)` - Withdraw your investment from a pool
- `deactivate-pool(pool-id)` - Deactivate a pool (pool owner only)

## 📋 Usage Examples

### Creating a Farmland Pool
```clarity
(contract-call? .Fractional-Farmland-Investment-Platform create-farmland-pool "Iowa Corn Farm" u1000000 u8)
```

### Investing in a Pool
```clarity
(contract-call? .Fractional-Farmland-Investment-Platform invest-in-pool u1 u50000)
```

### Distributing Yield (Pool Owner)
```clarity
(contract-call? .Fractional-Farmland-Investment-Platform distribute-yield u1 u80000)
```

### Claiming Yield Tokens
```clarity
(contract-call? .Fractional-Farmland-Investment-Platform claim-yield-tokens)
```

### Withdrawing Investment
```clarity
(contract-call? .Fractional-Farmland-Investment-Platform withdraw-investment u1 u25000)
```

## 🏗️ Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/marksngalda23/Fractional-Farmland-Investment-Platform
   cd Fractional-Farmland-Investment-Platform
   ```

2. **Install Clarinet**
   ```bash
   npm install -g @hirosystems/clarinet-cli
   ```

3. **Check contract syntax**
   ```bash
   clarinet check
   ```

4. **Run tests**
   ```bash
   clarinet test
   ```

5. **Deploy locally**
   ```bash
   clarinet console
   ```

## 💡 How It Works

1. **Pool Creation** 🎯: Farmland owners create investment pools with location, target amount, and expected yield rate
2. **Investment** 💰: Multiple investors contribute STX tokens to reach the funding target
3. **Yield Generation** 🌾: Pool owners manage farmland and generate agricultural profits
4. **Distribution** 📈: Yields are distributed proportionally to investors as yield tokens
5. **Claiming** 🏦: Investors can claim yield tokens and convert them back to STX

## 🔍 Pool Structure

Each farmland pool contains:
- **Owner**: Pool creator and manager
- **Location**: Farmland location description  
- **Total Value**: Estimated farmland value
- **Target Amount**: Funding goal for the pool
- **Yield Rate**: Expected annual yield percentage
- **Active Status**: Whether the pool accepts new investments

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines and submit pull requests for any improvements.

## 📄 License

MIT License - see LICENSE file for details.

---

*Built with 💚 on Stacks blockchain for sustainable agriculture investment*
