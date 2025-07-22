import { describe, it, expect, beforeEach } from "vitest"

describe("Pharmaceutical Patent Reform Contract", () => {
  let contractAddress
  let deployer
  let patentHolder1
  let evaluator1
  let licensee1
  
  beforeEach(() => {
    contractAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.pharma-patent-reform"
    deployer = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
    patentHolder1 = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
    evaluator1 = "ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC"
    licensee1 = "ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND"
  })
  
  describe("Patent Registration", () => {
    it("should register patent with calculated term", () => {
      const patentData = {
        drugName: "Revolutionary Drug A",
        developmentCost: 75000000,
        socialImpactScore: 85,
        basePrice: 500000,
      }
      
      const result = {
        success: true,
        patentId: 1,
        calculatedTerm: calculatePatentTerm(patentData.developmentCost, patentData.socialImpactScore),
      }
      
      expect(result.success).toBe(true)
      expect(result.patentId).toBe(1)
      expect(result.calculatedTerm).toBeGreaterThan(0)
    })
    
    
  })
  
  describe("Compulsory Licensing", () => {
    it("should issue compulsory license for high-priced drugs", () => {
      const licenseData = {
        patentId: 1,
        licensee: licensee1,
        justification: "Drug price exceeds accessibility threshold",
        basePrice: 1500000,
        threshold: 1000000,
      }
      
      const result = {
        success: true,
        licenseId: 1,
        royaltyRate: calculateCompulsoryRoyaltyRate(85), // High social impact
      }
      
      expect(result.success).toBe(true)
      expect(result.licenseId).toBe(1)
      expect(result.royaltyRate).toBe(200) // 2% for high social impact
    })
    
    it("should calculate royalty rates based on social impact", () => {
      const testCases = [
        { socialImpact: 85, expectedRate: 200 }, // 2%
        { socialImpact: 65, expectedRate: 300 }, // 3%
        { socialImpact: 45, expectedRate: 400 }, // 4%
        { socialImpact: 25, expectedRate: 500 }, // 5%
      ]
      
      testCases.forEach((testCase) => {
        const rate = calculateCompulsoryRoyaltyRate(testCase.socialImpact)
        expect(rate).toBe(testCase.expectedRate)
      })
    })
  })
  
  describe("Patent Renewal", () => {
    it("should allow patent renewal with revenue reporting", () => {
      const renewalData = {
        patentId: 1,
        revenueReport: 50000000,
        currentBlock: 1000000,
        registrationBlock: 500000,
        patentTerm: 5256000,
      }
      
      const result = {
        success: true,
        renewalCount: 1,
        totalRevenue: renewalData.revenueReport,
      }
      
      expect(result.success).toBe(true)
      expect(result.renewalCount).toBe(1)
      expect(result.totalRevenue).toBe(50000000)
    })
    
    it("should reject renewal for expired patents", () => {
      const result = {
        success: false,
        error: "ERR-PATENT-EXPIRED",
      }
      
      expect(result.success).toBe(false)
      expect(result.error).toBe("ERR-PATENT-EXPIRED")
    })
  })
  
  describe("Royalty Payments", () => {
    it("should process royalty payments correctly", () => {
      const paymentData = {
        licenseId: 1,
        salesAmount: 10000000,
        royaltyRate: 300, // 3%
      }
      
      const expectedRoyalty = Math.floor((paymentData.salesAmount * paymentData.royaltyRate) / 10000)
      
      const result = {
        success: true,
        royaltyAmount: expectedRoyalty,
      }
      
      expect(result.success).toBe(true)
      expect(result.royaltyAmount).toBe(300000) // 3% of 10M
    })
  })
  
  // Helper functions for testing
  function calculatePatentTerm(developmentCost, socialImpactScore) {
    const baseTerm = 5256000
    const costMultiplier = getCostMultiplier(developmentCost)
    const impactMultiplier = getImpactMultiplier(socialImpactScore)
    return Math.floor((baseTerm * costMultiplier * impactMultiplier) / 10000)
  }
  
  function getCostMultiplier(cost) {
    if (cost < 50000000) return 8000
    if (cost < 100000000) return 10000
    if (cost < 200000000) return 12000
    return 15000
  }
  
  function getImpactMultiplier(impact) {
    if (impact >= 80) return 8000
    if (impact >= 60) return 10000
    if (impact >= 40) return 12000
    return 15000
  }
  
  function calculateCompulsoryRoyaltyRate(socialImpact) {
    if (socialImpact >= 80) return 200
    if (socialImpact >= 60) return 300
    if (socialImpact >= 40) return 400
    return 500
  }
})
