# SecureDrop Community Network

## Overview

SecureDrop Community Network is a decentralized platform for secure, anonymous document sharing and whistleblowing, built on the Stacks blockchain. This system provides a trustless infrastructure for whistleblowers to safely submit documents while maintaining their anonymity, and for verified journalists to access these submissions securely.

## Project Description

The SecureDrop Community Network leverages blockchain technology to create a more resilient and censorship-resistant alternative to traditional whistleblowing platforms. By utilizing the Stacks blockchain's smart contract capabilities, we ensure that the system remains operational even if individual nodes or components are compromised.

## Architecture

The system consists of two main smart contracts:

### 1. Tor-Based Submission System (`tor-based-submission-system`)
- **Purpose**: Anonymous document submission with metadata scrubbing
- **Features**:
  - Anonymous document hash storage
  - Metadata sanitization and removal
  - Tor network integration for enhanced anonymity
  - Submission verification and validation
  - Encrypted document references

### 2. Journalist Verification Network (`journalist-verification-network`)
- **Purpose**: Secure channels for verified journalist access to submissions
- **Features**:
  - Journalist identity verification and registry
  - Secure access control mechanisms
  - Submission access logging and audit trails
  - Multi-signature verification for sensitive documents
  - Reputation system for journalists

## Key Features

- **Anonymity**: Complete anonymity for whistleblowers through Tor integration
- **Security**: End-to-end encryption and blockchain-based verification
- **Decentralization**: No single point of failure or control
- **Transparency**: All access attempts and verifications are logged on-chain
- **Resilience**: Censorship-resistant architecture
- **Verification**: Robust journalist verification system
- **Audit Trail**: Immutable record of all system interactions

## Security Model

1. **Anonymous Submissions**: Whistleblowers can submit documents without revealing their identity
2. **Metadata Scrubbing**: All identifying metadata is removed from submissions
3. **Encrypted Storage**: Document hashes and references are encrypted
4. **Verified Access**: Only verified journalists can access submissions
5. **Audit Logging**: All access attempts are recorded immutably

## Technical Stack

- **Blockchain**: Stacks blockchain
- **Smart Contracts**: Clarity language
- **Privacy**: Tor network integration
- **Encryption**: Advanced cryptographic protocols
- **Development**: Clarinet framework

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/edetut273-sys/SecureDrop-Community-Network.git
cd SecureDrop-Community-Network
```

2. Install dependencies:
```bash
npm install
```

3. Run contract checks:
```bash
clarinet check
```

4. Run tests:
```bash
clarinet test
```

## Contract Deployment

The contracts can be deployed to different networks:

- **Devnet**: For local development and testing
- **Testnet**: For staging and integration testing
- **Mainnet**: For production deployment

## Usage

### For Whistleblowers
1. Connect through Tor for anonymity
2. Submit document hashes through the submission system
3. Metadata is automatically scrubbed
4. Receive confirmation of successful submission

### For Journalists
1. Complete verification process
2. Register with the journalist verification network
3. Access verified submissions securely
4. All access is logged for audit purposes

## Contributing

We welcome contributions from the community. Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Security Considerations

- Always use Tor when interacting with the system
- Verify journalist credentials independently
- Report security vulnerabilities responsibly
- Follow operational security best practices

## License

This project is open source and available under the MIT License.

## Contact

For questions, concerns, or reporting security issues, please use secure communication channels and follow responsible disclosure practices.

## Roadmap

- [ ] Enhanced encryption protocols
- [ ] Mobile application development
- [ ] Integration with additional privacy networks
- [ ] Advanced journalist verification methods
- [ ] Decentralized governance mechanisms

---

*This project is designed to support freedom of information and press while maintaining the highest standards of security and privacy.*