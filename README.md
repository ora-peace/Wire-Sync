# Wire Sync - Decentralized Journalism Funding Platform

A smart contract built on the Stacks blockchain that enables decentralized funding for journalism with built-in reputation systems and impact metrics tracking.

## Overview

Wire Sync creates a trustless platform where journalists can create funding campaigns for their articles, community members can fund quality journalism, and reputation is built through transparent impact metrics. The platform incentivizes quality journalism through a comprehensive reputation system that tracks success rates, funding raised, and community impact.

## Features

### 🎯 Core Functionality
- **Article Funding Campaigns**: Journalists create funding goals with deadlines
- **Community Funding**: Supporters fund articles with STX tokens
- **Automated Fund Release**: Funds automatically released when goals are met
- **Impact Tracking**: Comprehensive metrics for article performance
- **Reputation System**: On-chain reputation scores for journalists

### 📊 Impact Metrics
- **Views**: Article readership tracking
- **Shares**: Social media distribution metrics
- **Citations**: Academic and media references
- **Verified Sources**: Quality journalism indicators
- **Community Rating**: Peer review scores

### 🏆 Reputation System
Reputation scores calculated based on:
- **Success Rate**: Completed vs. total articles (weighted heavily)
- **Funding Volume**: Total amount raised across campaigns
- **Impact Scores**: Average impact across completed articles
- **Bonus Factors**: Additional rewards for high-funding campaigns

## Contract Architecture

### Data Structures

#### Articles
```clarity
{
  journalist: principal,
  title: (string-ascii 100),
  funding-goal: uint,
  current-funding: uint,
  deadline: uint,
  impact-score: uint,
  status: (string-ascii 20), // "active", "funded", "completed", "cancelled"
  created-at: uint
}
```

#### Journalist Reputation
```clarity
{
  total-articles: uint,
  successful-articles: uint,
  total-funding-raised: uint,
  average-impact-score: uint,
  reputation-score: uint
}
```

#### Impact Metrics
```clarity
{
  views: uint,
  shares: uint,
  citations: uint,
  verified-sources: uint,
  community-rating: uint,
  last-updated: uint
}
```

## Public Functions

### 📝 Article Management

#### `create-article`
Creates a new funding campaign for an article.

**Parameters:**
- `title`: Article title (max 100 characters)
- `funding-goal`: Target funding amount in microSTX
- `deadline`: Block height deadline for funding

**Requirements:**
- Funding goal must exceed minimum amount (1 STX default)
- Deadline must be in the future

**Returns:** Article ID

#### `complete-article`
Marks an article as completed (journalist only).

**Parameters:**
- `article-id`: ID of the article to complete

**Requirements:**
- Only the journalist can call this function
- Article must be in "funded" status

### 💰 Funding Functions

#### `fund-article`
Fund an active article campaign.

**Parameters:**
- `article-id`: ID of the article to fund
- `amount`: Funding amount in microSTX

**Features:**
- Platform fee automatically deducted (2.5% default)
- Automatic status change to "funded" when goal is reached
- Funder records maintained for transparency

#### `withdraw-funds`
Allows journalists to withdraw funds from funded articles.

**Parameters:**
- `article-id`: ID of the funded article

**Requirements:**
- Only the journalist can withdraw
- Article must be in "funded" status

### 📈 Impact & Reputation

#### `update-impact-metrics`
Updates article performance metrics.

**Parameters:**
- `article-id`: Article to update
- `views`: Total article views
- `shares`: Social media shares
- `citations`: Academic/media citations
- `verified-sources`: Number of verified sources used
- `community-rating`: Community-assigned quality rating

**Authorization:**
- Article journalist or contract owner only

**Impact Score Calculation:**
```
impact-score = (views × 1) + (shares × 3) + (citations × 5) + 
               (verified-sources × 10) + (community-rating × 2)
```

### 📊 Read-Only Functions

#### `get-article`
Retrieves article details by ID.

#### `get-journalist-reputation`
Gets reputation data for a journalist.

#### `get-funding-details`
Gets funding information for a specific funder and article.

#### `get-impact-metrics`
Retrieves impact metrics for an article.

#### `calculate-reputation-score`
Calculates current reputation score for a journalist.

**Formula:**
```clarity
reputation = success-rate × 100 + funding-bonus + impact-factor
where:
- success-rate = (successful-articles / total-articles) × 100
- funding-bonus = 50 if total-funding > 10 STX, else 0
- impact-factor = average-impact-score / 10
```

## Administrative Functions

### `set-platform-fee-rate`
Updates the platform fee rate (owner only).
- Maximum: 10% (1000 basis points)
- Default: 2.5% (250 basis points)

### `set-min-funding-amount`
Updates minimum funding requirement (owner only).

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `err-owner-only` | Function restricted to contract owner |
| u101 | `err-not-found` | Article or data not found |
| u102 | `err-insufficient-funds` | Insufficient balance for operation |
| u103 | `err-unauthorized` | Unauthorized access attempt |
| u104 | `err-already-exists` | Duplicate entry attempt |
| u105 | `err-invalid-amount` | Invalid amount provided |

## Usage Examples

### Creating an Article Campaign

```clarity
;; Create a funding campaign for $100 with 1000 block deadline
(contract-call? .wire-sync create-article 
  "Investigating Local Corruption" 
  u100000000  ;; 100 STX in microSTX
  u1001000)   ;; Block height deadline
```

### Funding an Article

```clarity
;; Fund article #1 with 10 STX
(contract-call? .wire-sync fund-article u1 u10000000)
```

### Updating Impact Metrics

```clarity
;; Update metrics for completed article
(contract-call? .wire-sync update-impact-metrics 
  u1      ;; article-id
  u5000   ;; views
  u200    ;; shares
  u15     ;; citations
  u8      ;; verified-sources
  u85)    ;; community-rating (out of 100)
```

## Deployment

1. **Prerequisites:**
   - Clarinet CLI installed
   - Stacks wallet configured
   - STX tokens for deployment

2. **Local Testing:**
   ```bash
   clarinet check
   clarinet test
   ```

3. **Deployment:**
   ```bash
   clarinet deploy --testnet
   ```

## Security Considerations

### ✅ Security Features
- **Access Control**: Role-based permissions for sensitive operations
- **Input Validation**: Comprehensive parameter checking
- **Safe Transfers**: Uses Stacks standard transfer functions
- **Overflow Protection**: Careful arithmetic operations

### ⚠️ Important Notes
- Platform fees are collected but not automatically distributed
- Article deadlines are based on block height, not timestamp
- Reputation scores can only increase (no penalties for failed campaigns)
- Impact metrics updates require manual input (off-chain data integration needed)

## Integration Guide

### Frontend Integration

The contract provides comprehensive read functions for building user interfaces:

```javascript
// Get article details
const article = await callReadOnlyFunction({
  contractName: 'wire-sync',
  functionName: 'get-article',
  functionArgs: [uintCV(articleId)]
});

// Check journalist reputation
const reputation = await callReadOnlyFunction({
  contractName: 'wire-sync',
  functionName: 'get-journalist-reputation',
  functionArgs: [principalCV(journalistAddress)]
});
```

### Event Monitoring

Monitor contract events for real-time updates:
- Article creation
- Funding milestones
- Goal completions
- Impact metric updates

## Roadmap

### Phase 1 (Current)
- ✅ Basic funding mechanics
- ✅ Reputation system
- ✅ Impact metrics tracking

### Phase 2 (Planned)
- Multi-token support (other SIP-010 tokens)
- Automated impact data feeds
- Governance mechanisms for dispute resolution
- NFT certificates for completed articles

### Phase 3 (Future)
- Cross-chain compatibility
- Advanced analytics dashboard
- Journalist verification system
- Subscription-based funding models

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License.
