# Script to commit and push all changes for finance role fix and dashboard

Write-Host "📦 Checking git status..." -ForegroundColor Cyan
git status

Write-Host "`n➕ Adding all changes..." -ForegroundColor Cyan
git add .

Write-Host "`n💾 Committing changes..." -ForegroundColor Cyan
git commit -m "Fix finance manager role registration, login routing, and deploy finance dashboard

- Fixed backend registration to save 'finance_manager' role correctly
- Fixed backend login to normalize finance roles properly  
- Updated frontend RoleService to recognize all finance role variations
- Updated login and register pages to route finance users correctly
- Added finance role support to main.dart and animated_landing_page_v2.dart
- Added SQL scripts for database role updates"

Write-Host "`n🚀 Pushing to Cleaned_Code branch..." -ForegroundColor Cyan
git push origin Cleaned_Code

Write-Host "`n✅ Done! Changes pushed to Cleaned_Code branch." -ForegroundColor Green
Write-Host "⏳ Render will automatically deploy the changes." -ForegroundColor Yellow

