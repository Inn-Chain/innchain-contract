# InnChain 🏨⛓️

[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-363636?style=for-the-badge&logo=solidity)](https://soliditylang.org/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.0.0-4E5EE4?style=for-the-badge&logo=openzeppelin)](https://openzeppelin.com/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C?style=for-the-badge)](https://book.getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

> A decentralized hotel booking system with escrow payments and tokenized deposits powered by blockchain technology.

## 🌟 Overview

InnChain solves the trust problem between hotels and customers by implementing a smart contract-based escrow mechanism. Payments for rooms and deposits are securely held in the contract and released only when predetermined conditions are met.

### ✨ Key Features

- 🏢 **Multi-Class Room System** - Hotels can define various room classes (Standard, Deluxe, Suite, etc.) with different pricing
- 🔒 **Escrow Payment** - Customer funds are locked in smart contract until check-in is confirmed
- 💰 **Tokenized Deposit** - Deposits paid in stablecoins can be charged partially or fully for damages
- 🔄 **Flexible Refund** - Support for full refunds on cancellations or partial refunds for deposits
- 🔍 **Transparent & Trustless** - All transactions are on-chain and verifiable

## 🛠 Tech Stack

- **Solidity** ^0.8.20
- **Foundry** for development & testing
- **OpenZeppelin Contracts** (Ownable, IERC20)
- **Stablecoins** as payment method (USDC, USDT, DAI, etc.)

## 📦 Installation

```bash
# Clone repository
git clone https://github.com/yourusername/innchain.git
cd innchain

# Install Foundry dependencies
forge install

# Install OpenZeppelin
forge install OpenZeppelin/openzeppelin-contracts
```

## 🚀 How It Works

### 1️⃣ Hotel Registration & Room Setup
Hotel owners register their property and set up room classes with individual pricing. Each hotel can have multiple room classes with different rates.

### 2️⃣ Customer Booking
Customers select a hotel, room class, number of nights, and deposit amount. The total payment (room cost + deposit) is transferred to the smart contract as escrow. Funds remain locked until confirmation or settlement.

### 3️⃣ Check-In Confirmation
Hotel confirms customer check-in. Upon confirmation, room cost is automatically released from escrow to the hotel wallet. Deposit remains held to cover potential damages or charges.

### 4️⃣ Check-Out & Deposit Settlement
After check-out, hotels have several options:
- **No damage**: Full deposit refunded to customer
- **Damages/charges**: Hotel charges deposit for the required amount, remainder returned to customer
- **Pre-check-in cancellation**: Full refund (room + deposit) can be processed by customer, hotel, or owner

## 🏗 Contract Architecture

### Core Components

**Hotel Management**
- Register hotels with wallet addresses for payments
- Add and update room classes with names and pricing
- Multiple room classes per hotel for flexibility

**Booking & Escrow System**
- Customers create bookings with locked funds in contract
- Hotels confirm check-in to release room payment
- Deposit settlement with multiple options (refund/charge)
- Full refund mechanism for cancellations

**Access Control**
- Hotel-specific actions restricted to hotel wallet
- Contract owner has override access for dispute resolution
- Customers can trigger full refund before check-in

## 📋 Main Functions

### Hotel Management
- `registerHotel(address wallet)` - Register new hotel
- `addRoomClass(hotelId, name, pricePerNight)` - Add room class
- `updateRoomClass(hotelId, classId, name, newPrice)` - Update room class

### Booking Operations
- `createBooking(hotelId, classId, nights, deposit)` - Create new booking
- `confirmCheckIn(bookingId)` - Hotel confirms check-in
- `refundDeposit(bookingId)` - Refund full deposit
- `chargeDeposit(bookingId, amount)` - Charge deposit for damages
- `fullRefund(bookingId)` - Cancel & refund everything

### View Functions
- `getHotel(hotelId)` - Hotel information
- `getRoomClass(hotelId, classId)` - Room class details
- `getBooking(bookingId)` - Booking details

## 📡 Events

The contract emits events for all critical actions:
- `HotelRegistered` - New hotel registered
- `RoomClassAdded` & `RoomClassUpdated` - Room class changes
- `BookingCreated` - New booking created
- `RoomPaymentReleased` - Payment to hotel
- `DepositRefunded` - Deposit returned
- `DepositCharged` - Deposit charged
- `FullRefund` - Full cancellation refund

## 🧪 Testing

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test
forge test --match-test testCreateBooking

# Coverage report
forge coverage

# Gas report
forge test --gas-report
```

## 🚢 Deployment

```bash
# Deploy to network (example: Polygon Mumbai testnet)
forge create src/InnChain.sol:InnChain \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args $STABLECOIN_ADDRESS

# Verify contract
forge verify-contract \
  --chain-id 80001 \
  --compiler-version v0.8.20 \
  $CONTRACT_ADDRESS \
  src/InnChain.sol:InnChain \
  --constructor-args $(cast abi-encode "constructor(address)" $STABLECOIN_ADDRESS)
```

## 🔐 Security Features

- ✅ Access control to prevent unauthorized actions
- ✅ State checks with flags to prevent double-spending
- ✅ Safe token transfers with require checks
- ✅ Owner override capability for dispute resolution
- ✅ OpenZeppelin battle-tested libraries

## 💼 Use Cases

### Standard Flow (Happy Path)
1. Hotel registers & sets up room classes
2. Customer books room with deposit
3. Hotel confirms check-in → room payment released
4. Customer checks out without damage
5. Hotel refunds full deposit

### Damage Scenario
1. Customer checks in (room payment released)
2. Damage occurs in the room
3. Hotel charges deposit partially/fully according to damage
4. Remainder (if any) refunded to customer

### Cancellation Flow
1. Customer books room
2. Before check-in, customer/hotel cancels
3. Full refund (room + deposit) to customer

## 🎯 Supported Networks

- Ethereum Mainnet
- Polygon
- Arbitrum
- Optimism
- Base
- Any EVM-compatible chain with stablecoin support

## 🔮 Roadmap

- [ ] Oracle integration for real-time room availability
- [ ] NFT as booking receipt/proof of stay
- [ ] On-chain rating & review system
- [ ] Multi-signature for large deposits
- [ ] Dynamic pricing based on demand
- [ ] Loyalty rewards token
- [ ] Multi-stablecoin support
- [ ] Batch operations for multiple bookings
- [ ] Dispute arbitration system

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="left">

**Built with ❤️ Inn Chain**

</div>