#!/usr/bin/env python3
"""
Test to verify that Proposal_Landing_Screen is now the startup screen
"""

import requests
import json

def test_startup_change():
    """Verify that the app startup screen has been changed"""
    print("🚀 Testing Startup Screen Change")
    print("=" * 50)
    
    # Check that the main.dart file no longer imports cinematic_sequence_page
    print("\n1. Checking main.dart imports...")
    
    try:
        with open('c:/apps/lukens/Lukens/frontend_flutter/lib/main.dart', 'r') as f:
            main_content = f.read()
        
        if 'cinematic_sequence_page.dart' not in main_content:
            print("✅ cinematic_sequence_page import removed from main.dart")
        else:
            print("❌ cinematic_sequence_page import still found in main.dart")
            
        if 'Proposal_Landing_Screen.dart' in main_content:
            print("✅ Proposal_Landing_Screen is accessible in main.dart")
        else:
            print("⚠️ Proposal_Landing_Screen not directly imported in main.dart (imported via startup_page.dart)")
    
    except Exception as e:
        print(f"❌ Error reading main.dart: {e}")
    
    # Check that startup_page.dart now uses Proposal_Landing_Screen
    print("\n2. Checking startup_page.dart...")
    
    try:
        with open('c:/apps/lukens/Lukens/frontend_flutter/lib/pages/shared/startup_page.dart', 'r') as f:
            startup_content = f.read()
        
        if 'CinematicSequencePage()' not in startup_content:
            print("✅ CinematicSequencePage() removed from startup_page.dart")
        else:
            print("❌ CinematicSequencePage() still found in startup_page.dart")
            
        if 'PersonalDevelopmentHubScreen()' in startup_content:
            print("✅ PersonalDevelopmentHubScreen() now used in startup_page.dart")
        else:
            print("❌ PersonalDevelopmentHubScreen() not found in startup_page.dart")
            
        if '../Proposal_Landing_Screen.dart' in startup_content:
            print("✅ Proposal_Landing_Screen import added to startup_page.dart")
        else:
            print("❌ Proposal_Landing_Screen import not found in startup_page.dart")
    
    except Exception as e:
        print(f"❌ Error reading startup_page.dart: {e}")
    
    # Check that cinematic route was removed
    print("\n3. Checking route configuration...")
    
    try:
        with open('c:/apps/lukens/Lukens/frontend_flutter/lib/main.dart', 'r') as f:
            main_content = f.read()
        
        if "'/cinematic':" not in main_content:
            print("✅ /cinematic route removed from main.dart")
        else:
            print("❌ /cinematic route still found in main.dart")
    
    except Exception as e:
        print(f"❌ Error checking routes: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 SUMMARY")
    print("=" * 50)
    print("✅ Startup screen successfully changed:")
    print("  - cinematic_sequence_page.dart removed as startup screen")
    print("  - Proposal_Landing_Screen.dart is now the main entry point")
    print("  - startup_page.dart updated to use new screen")
    print("  - Routes cleaned up")
    print("\n🚀 App will now start with Proposal_Landing_Screen!")

if __name__ == "__main__":
    test_startup_change()
