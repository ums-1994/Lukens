"""
Test Suite for Risk Gate System
Comprehensive tests for all risk analysis components
"""

import unittest
import os
import sys
from unittest.mock import Mock, patch

# Add the risk_gate directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from utils.file_loader import FileLoader
from utils.template_loader import TemplateLoader
from utils.scoring import RiskScorer
from analyzers.structural_analyzer import StructuralAnalyzer
from analyzers.clause_analyzer import ClauseAnalyzer
from analyzers.weakness_analyzer import WeaknessAnalyzer
from analyzers.semantic_ai_analyzer import SemanticAIAnalyzer
from risk_engine.risk_combiner import RiskCombiner
from risk_engine.risk_gate import RiskGate


class TestFileLoader(unittest.TestCase):
    """Test cases for FileLoader"""
    
    def setUp(self):
        self.file_loader = FileLoader()
    
    def test_load_direct_text(self):
        """Test loading text directly"""
        test_text = "This is a test proposal with some content."
        result = self.file_loader.load_proposal_text_direct(test_text)
        
        self.assertTrue(result['success'])
        self.assertEqual(result['text'], test_text)
        self.assertIn('word_count', result['metadata'])
        self.assertEqual(result['metadata']['word_count'], 8)
    
    def test_preprocess_text(self):
        """Test text preprocessing"""
        messy_text = "  This   is   a   test   \n\n\n  with   extra   spaces  "
        result = self.file_loader.preprocess_text(messy_text)
        
        self.assertEqual(result, "This is a test with extra spaces")
    
    def test_load_nonexistent_file(self):
        """Test loading non-existent file"""
        result = self.file_loader.load_proposal_text("nonexistent.txt")
        
        self.assertFalse(result['success'])
        self.assertIn('not found', result['error'])


class TestStructuralAnalyzer(unittest.TestCase):
    """Test cases for StructuralAnalyzer"""
    
    def setUp(self):
        self.analyzer = StructuralAnalyzer()
    
    def test_complete_proposal_structure(self):
        """Test analysis of complete proposal structure"""
        complete_text = """
        EXECUTIVE SUMMARY
        This is the executive summary content.
        
        SCOPE OF WORK
        The project will include the following scope...
        
        DELIVERABLES
        We will deliver the following items...
        
        TIMELINE
        The project timeline is as follows...
        
        BUDGET
        The total budget is $50,000...
        
        TEAM
        Our team consists of experienced professionals...
        
        ASSUMPTIONS
        We assume the following...
        """
        
        result = self.analyzer.analyze_structure(complete_text)
        
        self.assertGreater(result['structural_score'], 0.8)
        self.assertLess(len(result['missing_sections']), 2)
    
    def test_incomplete_proposal_structure(self):
        """Test analysis of incomplete proposal structure"""
        incomplete_text = """
        This is a basic proposal without proper sections.
        It mentions some budget information but lacks structure.
        """
        
        result = self.analyzer.analyze_structure(incomplete_text)
        
        self.assertLess(result['structural_score'], 0.5)
        self.assertGreater(len(result['missing_sections']), 3)


class TestWeaknessAnalyzer(unittest.TestCase):
    """Test cases for WeaknessAnalyzer"""
    
    def setUp(self):
        self.analyzer = WeaknessAnalyzer()
    
    def test_strong_proposal(self):
        """Test analysis of strong proposal"""
        strong_text = """
        Our team consists of 5 senior developers with 10+ years of experience each.
        The project timeline is 12 weeks with specific milestones.
        Budget breakdown: Development $30,000, Design $10,000, Testing $5,000.
        Scope includes specific deliverables with clear acceptance criteria.
        """
        
        result = self.analyzer.analyze_weaknesses(strong_text)
        
        self.assertLess(result['overall_weakness_score'], 0.4)
        self.assertLess(len(result['weak_areas']), 2)
    
    def test_weak_proposal(self):
        """Test analysis of weak proposal"""
        weak_text = """
        Our team has experience. Timeline will be around a few weeks.
        Budget is approximately reasonable price.
        Scope includes various deliverables.
        """
        
        result = self.analyzer.analyze_weaknesses(weak_text)
        
        self.assertGreater(result['overall_weakness_score'], 0.5)
        self.assertGreater(len(result['weak_areas']), 2)


class TestScoring(unittest.TestCase):
    """Test cases for RiskScorer"""
    
    def setUp(self):
        self.scorer = RiskScorer()
    
    def test_structural_risk_calculation(self):
        """Test structural risk score calculation"""
        # Good structure
        good_structure = {'structural_score': 0.9, 'missing_sections': []}
        risk_score = self.scorer.calculate_structural_risk_score(good_structure)
        self.assertLess(risk_score, 0.2)
        
        # Poor structure
        poor_structure = {'structural_score': 0.3, 'missing_sections': ['scope', 'budget']}
        risk_score = self.scorer.calculate_structural_risk_score(poor_structure)
        self.assertGreater(risk_score, 0.5)
    
    def test_compound_risk_calculation(self):
        """Test compound risk score calculation"""
        analysis_results = {
            'structural_analysis': {'structural_score': 0.8, 'missing_sections': []},
            'clause_analysis': {'clause_risk_score': 0.3, 'altered_clauses': [], 'missing_clauses': []},
            'weakness_analysis': {'overall_weakness_score': 0.2, 'weak_areas': []},
            'semantic_analysis': {'semantic_risk_score': 0.1, 'ai_semantic_flags': []}
        }
        
        result = self.scorer.calculate_compound_risk_score(analysis_results)
        
        self.assertIn('compound_risk_score', result)
        self.assertIn('risk_level', result)
        self.assertIn('compound_risk', result)
        self.assertLess(result['compound_risk_score'], 0.5)


class TestRiskCombiner(unittest.TestCase):
    """Test cases for RiskCombiner"""
    
    def setUp(self):
        self.combiner = RiskCombiner()
    
    def test_risk_combination(self):
        """Test risk combination logic"""
        analysis_results = {
            'structural_analysis': {
                'structural_score': 0.7,
                'missing_sections': ['assumptions'],
                'present_sections': ['scope', 'budget', 'deliverables']
            },
            'clause_analysis': {
                'clause_risk_score': 0.4,
                'altered_clauses': [],
                'missing_clauses': ['ip_clause']
            },
            'weakness_analysis': {
                'overall_weakness_score': 0.3,
                'weak_areas': [{'type': 'weak_timeline', 'severity': 'low'}]
            },
            'semantic_analysis': {
                'semantic_risk_score': 0.2,
                'ai_semantic_flags': []
            }
        }
        
        result = self.combiner.combine_risk_analysis(analysis_results)
        
        self.assertIn('risk_score', result)
        self.assertIn('compound_risk', result)
        self.assertIn('decision', result)
        self.assertIn('summary', result)
        self.assertIn('recommendations', result)
    
    def test_high_risk_decision(self):
        """Test high risk decision making"""
        scoring_results = {
            'compound_risk_score': 0.8,
            'risk_level': 'high',
            'component_risks': {
                'structural': 0.9,
                'clause': 0.7,
                'weakness': 0.6,
                'semantic': 0.4
            }
        }
        
        decision = self.combiner._make_risk_decision(scoring_results)
        
        self.assertIn('decision', decision)
        self.assertIn('compound_risk', decision)
        self.assertIn('confidence', decision)
        self.assertTrue(decision['compound_risk'])


class TestRiskGate(unittest.TestCase):
    """Test cases for main RiskGate"""
    
    def setUp(self):
        # Mock template loader to avoid dependency on actual files
        with patch('risk_gate.utils.template_loader.TemplateLoader'):
            self.risk_gate = RiskGate()
    
    def test_proposal_analysis_basic(self):
        """Test basic proposal analysis"""
        proposal_text = """
        EXECUTIVE SUMMARY
        This proposal outlines our approach to the project.
        
        SCOPE OF WORK
        We will complete the following work...
        
        BUDGET
        Total cost is $25,000 for all deliverables.
        
        TIMELINE
        Project will be completed in 8 weeks.
        """
        
        # Mock the analyzers to return simple results
        with patch.object(self.risk_gate.structural_analyzer, 'analyze_structure') as mock_structural, \
             patch.object(self.risk_gate.clause_analyzer, 'analyze_clauses') as mock_clause, \
             patch.object(self.risk_gate.weakness_analyzer, 'analyze_weaknesses') as mock_weakness, \
             patch.object(self.risk_gate.semantic_analyzer, 'analyze_semantic_risks') as mock_semantic:
            
            # Set up mock returns
            mock_structural.return_value = {'structural_score': 0.8, 'missing_sections': []}
            mock_clause.return_value = {'clause_risk_score': 0.2, 'altered_clauses': [], 'missing_clauses': []}
            mock_weakness.return_value = {'overall_weakness_score': 0.1, 'weak_areas': []}
            mock_semantic.return_value = {'semantic_risk_score': 0.1, 'ai_semantic_flags': []}
            
            result = self.risk_gate.analyze_proposal(proposal_text)
            
            self.assertTrue(result['success'])
            self.assertIn('risk_score', result)
            self.assertIn('compound_risk', result)
            self.assertIn('summary', result)
    
    def test_quick_risk_assessment(self):
        """Test quick risk assessment"""
        proposal_text = """
        This proposal includes budget information and timeline details.
        The scope of work is clearly defined.
        Our team has relevant experience.
        """
        
        result = self.risk_gate.get_quick_risk_assessment(proposal_text)
        
        self.assertIn('word_count', result)
        self.assertIn('has_budget', result)
        self.assertIn('has_timeline', result)
        self.assertIn('estimated_risk', result)
        self.assertIn('completeness_score', result)
    
    def test_system_status(self):
        """Test system status check"""
        result = self.risk_gate.get_system_status()
        
        self.assertIn('system_status', result)
        self.assertIn('analyzers_available', result)
        self.assertIn('version', result)


class TestIntegration(unittest.TestCase):
    """Integration tests for the complete system"""
    
    def test_end_to_end_analysis(self):
        """Test end-to-end analysis with sample proposal"""
        sample_proposal = """
        EXECUTIVE SUMMARY
        This proposal provides a comprehensive solution for the client's needs.
        
        SCOPE OF WORK
        The project includes software development, testing, and deployment.
        We will develop a web application with user authentication and data management.
        
        DELIVERABLES
        1. Fully functional web application
        2. User documentation
        3. Technical documentation
        4. Testing reports
        
        TIMELINE
        Phase 1: Requirements gathering (2 weeks)
        Phase 2: Development (6 weeks)
        Phase 3: Testing (2 weeks)
        Phase 4: Deployment (1 week)
        
        BUDGET
        Development: $40,000
        Testing: $8,000
        Documentation: $4,000
        Total: $52,000
        
        TEAM
        John Doe - Project Manager (10 years experience)
        Jane Smith - Lead Developer (8 years experience)
        Bob Johnson - QA Engineer (5 years experience)
        
        ASSUMPTIONS
        - Client will provide timely feedback
        - Requirements will not change significantly
        - Testing environment will be provided
        
        INTELLECTUAL PROPERTY
        All code developed becomes client property upon final payment.
        
        PAYMENT TERMS
        30% upfront, 40% upon milestone completion, 30% on delivery.
        """
        
        # Test with mocked dependencies to avoid file system dependencies
        with patch('risk_gate.utils.template_loader.TemplateLoader'), \
             patch('risk_gate.analyzers.clause_analyzer.ClauseAnalyzer') as mock_clause, \
             patch('risk_gate.analyzers.semantic_ai_analyzer.SemanticAIAnalyzer') as mock_semantic:
            
            # Create a real risk gate but with mocked components
            risk_gate = RiskGate()
            
            # Mock the clause and semantic analyzers
            mock_clause.return_value.analyze_clauses.return_value = {
                'clause_risk_score': 0.1,
                'altered_clauses': [],
                'missing_clauses': []
            }
            
            mock_semantic.return_value.analyze_semantic_risks.return_value = {
                'semantic_risk_score': 0.1,
                'ai_semantic_flags': []
            }
            
            result = risk_gate.analyze_proposal(sample_proposal)
            
            self.assertTrue(result['success'])
            self.assertLess(result['risk_score'], 0.5)  # Should be low risk for good proposal
            self.assertFalse(result['compound_risk'])  # Should not be blocked


def run_tests():
    """Run all tests"""
    # Create test suite
    test_suite = unittest.TestSuite()
    
    # Add test cases
    test_classes = [
        TestFileLoader,
        TestStructuralAnalyzer,
        TestWeaknessAnalyzer,
        TestScoring,
        TestRiskCombiner,
        TestRiskGate,
        TestIntegration
    ]
    
    for test_class in test_classes:
        tests = unittest.TestLoader().loadTestsFromTestCase(test_class)
        test_suite.addTests(tests)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(test_suite)
    
    return result.wasSuccessful()


if __name__ == '__main__':
    print("Running Risk Gate Test Suite...")
    print("=" * 50)
    
    success = run_tests()
    
    print("=" * 50)
    if success:
        print("✅ All tests passed!")
    else:
        print("❌ Some tests failed!")
    
    print(f"Tests run: {unittest.TestResult().testsRun}")
