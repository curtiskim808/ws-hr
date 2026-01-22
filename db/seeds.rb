# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Seed Data Structure:
# - 2 brands (nike, adidas)
# - 2 locations for each brand (Vancouver, Toronto)
# - 4 users for each brand (1 super_admin, 1 admin, 1 hiring_manager, 1 interviewer)
# - 1 hiring process for each brand with 4 stages
# - 3 position templates for each brand
# - 2 job postings for each brand

puts "🌱 Seeding database..."

# =============================================================================
# BRANDS
# =============================================================================

nike = Brand.find_or_create_by!(subdomain: 'nike') do |b|
  b.name = 'Nike'
  b.settings = {}
end

adidas = Brand.find_or_create_by!(subdomain: 'adidas') do |b|
  b.name = 'Adidas'
  b.settings = {}
end

puts "✅ Created brands: #{nike.name}, #{adidas.name}"

# =============================================================================
# LOCATIONS
# =============================================================================

# Nike locations
nike_vancouver = Location.find_or_create_by!(brand: nike, name: 'Vancouver') do |l|
  l.address = '123 Main Street'
  l.city = 'Vancouver'
  l.state = 'BC'
  l.postal_code = 'V6B 1A1'
  l.country = 'Canada'
  l.timezone = 'America/Vancouver'
end

nike_toronto = Location.find_or_create_by!(brand: nike, name: 'Toronto') do |l|
  l.address = '456 Queen Street'
  l.city = 'Toronto'
  l.state = 'ON'
  l.postal_code = 'M5H 2M9'
  l.country = 'Canada'
  l.timezone = 'America/Toronto'
end

# Adidas locations
adidas_vancouver = Location.find_or_create_by!(brand: adidas, name: 'Vancouver') do |l|
  l.address = '789 Granville Street'
  l.city = 'Vancouver'
  l.state = 'BC'
  l.postal_code = 'V6Z 1K2'
  l.country = 'Canada'
  l.timezone = 'America/Vancouver'
end

adidas_toronto = Location.find_or_create_by!(brand: adidas, name: 'Toronto') do |l|
  l.address = '321 Bay Street'
  l.city = 'Toronto'
  l.state = 'ON'
  l.postal_code = 'M5J 2N8'
  l.country = 'Canada'
  l.timezone = 'America/Toronto'
end

puts "✅ Created locations for both brands"

# =============================================================================
# USERS
# =============================================================================

# Nike users
nike_super_admin = User.find_or_create_by!(brand: nike, email: 'admin@nike.com') do |u|
  u.first_name = 'Nike'
  u.last_name = 'Super Admin'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :super_admin
end

nike_admin = User.find_or_create_by!(brand: nike, email: 'manager@nike.com') do |u|
  u.first_name = 'Nike'
  u.last_name = 'Admin'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :admin
end

nike_hiring_manager = User.find_or_create_by!(brand: nike, email: 'hiring@nike.com') do |u|
  u.first_name = 'Nike'
  u.last_name = 'Hiring Manager'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :hiring_manager
end

nike_interviewer = User.find_or_create_by!(brand: nike, email: 'interviewer@nike.com') do |u|
  u.first_name = 'Nike'
  u.last_name = 'Interviewer'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :interviewer
end

# Adidas users
adidas_super_admin = User.find_or_create_by!(brand: adidas, email: 'admin@adidas.com') do |u|
  u.first_name = 'Adidas'
  u.last_name = 'Super Admin'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :super_admin
end

adidas_admin = User.find_or_create_by!(brand: adidas, email: 'manager@adidas.com') do |u|
  u.first_name = 'Adidas'
  u.last_name = 'Admin'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :admin
end

adidas_hiring_manager = User.find_or_create_by!(brand: adidas, email: 'hiring@adidas.com') do |u|
  u.first_name = 'Adidas'
  u.last_name = 'Hiring Manager'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :hiring_manager
end

adidas_interviewer = User.find_or_create_by!(brand: adidas, email: 'interviewer@adidas.com') do |u|
  u.first_name = 'Adidas'
  u.last_name = 'Interviewer'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :interviewer
end

# Assign hiring managers and interviewers to locations
LocationAssignment.find_or_create_by!(user: nike_hiring_manager, location: nike_vancouver)
LocationAssignment.find_or_create_by!(user: nike_hiring_manager, location: nike_toronto)
LocationAssignment.find_or_create_by!(user: nike_interviewer, location: nike_vancouver)

LocationAssignment.find_or_create_by!(user: adidas_hiring_manager, location: adidas_vancouver)
LocationAssignment.find_or_create_by!(user: adidas_hiring_manager, location: adidas_toronto)
LocationAssignment.find_or_create_by!(user: adidas_interviewer, location: adidas_vancouver)

puts "✅ Created users for both brands"

# =============================================================================
# HIRING PROCESSES & STAGES
# =============================================================================

# Nike hiring process
nike_process = HiringProcess.find_or_create_by!(brand: nike, name: 'Standard Hiring Process') do |hp|
  hp.description = 'Standard hiring process for most positions'
  hp.is_default = true
  hp.active = true
end

# Nike hiring stages
nike_stage1 = HiringStage.find_or_create_by!(hiring_process: nike_process, position: 1) do |hs|
  hs.name = 'Application Review'
  hs.stage_type = :application
  hs.required = true
  hs.settings = {}
end

nike_stage2 = HiringStage.find_or_create_by!(hiring_process: nike_process, position: 2) do |hs|
  hs.name = 'Phone Screen'
  hs.stage_type = :interview
  hs.required = true
  hs.settings = { duration_minutes: 30 }
end

nike_stage3 = HiringStage.find_or_create_by!(hiring_process: nike_process, position: 3) do |hs|
  hs.name = 'Technical Interview'
  hs.stage_type = :interview
  hs.required = true
  hs.settings = { duration_minutes: 60 }
end

nike_stage4 = HiringStage.find_or_create_by!(hiring_process: nike_process, position: 4) do |hs|
  hs.name = 'Final Decision'
  hs.stage_type = :decision
  hs.required = true
  hs.settings = {}
end

# Adidas hiring process
adidas_process = HiringProcess.find_or_create_by!(brand: adidas, name: 'Standard Hiring Process') do |hp|
  hp.description = 'Standard hiring process for most positions'
  hp.is_default = true
  hp.active = true
end

# Adidas hiring stages
adidas_stage1 = HiringStage.find_or_create_by!(hiring_process: adidas_process, position: 1) do |hs|
  hs.name = 'Application Review'
  hs.stage_type = :application
  hs.required = true
  hs.settings = {}
end

adidas_stage2 = HiringStage.find_or_create_by!(hiring_process: adidas_process, position: 2) do |hs|
  hs.name = 'Phone Screen'
  hs.stage_type = :interview
  hs.required = true
  hs.settings = { duration_minutes: 30 }
end

adidas_stage3 = HiringStage.find_or_create_by!(hiring_process: adidas_process, position: 3) do |hs|
  hs.name = 'Technical Interview'
  hs.stage_type = :interview
  hs.required = true
  hs.settings = { duration_minutes: 60 }
end

adidas_stage4 = HiringStage.find_or_create_by!(hiring_process: adidas_process, position: 4) do |hs|
  hs.name = 'Final Decision'
  hs.stage_type = :decision
  hs.required = true
  hs.settings = {}
end

puts "✅ Created hiring processes with stages for both brands"

# =============================================================================
# POSITION TEMPLATES
# =============================================================================

# Nike position templates
nike_template1 = PositionTemplate.find_or_create_by!(brand: nike, name: 'Software Engineer') do |pt|
  pt.job_title = 'Software Engineer'
  pt.category = 'Engineering'
  pt.department = 'Product Development'
  pt.description = 'We are looking for a talented Software Engineer to join our team. You will work on building scalable applications and solving complex technical challenges.'
  pt.requirements = '• 3+ years of experience in software development\n• Strong knowledge of Ruby on Rails\n• Experience with PostgreSQL\n• Excellent problem-solving skills'
  pt.location_type = 'hybrid'
  pt.employment_type = 'full_time'
  pt.education_requirement = 'bachelor'
  pt.status = :active
end

nike_template2 = PositionTemplate.find_or_create_by!(brand: nike, name: 'Sales Representative') do |pt|
  pt.job_title = 'Sales Representative'
  pt.category = 'Sales'
  pt.department = 'Sales'
  pt.description = 'Join our sales team and help drive revenue growth. You will manage client relationships and close deals.'
  pt.requirements = '• 2+ years of sales experience\n• Excellent communication skills\n• Proven track record of meeting sales targets\n• Customer-focused mindset'
  pt.location_type = 'onsite'
  pt.employment_type = 'full_time'
  pt.education_requirement = 'high_school'
  pt.status = :active
end

nike_template3 = PositionTemplate.find_or_create_by!(brand: nike, name: 'Customer Support Specialist') do |pt|
  pt.job_title = 'Customer Support Specialist'
  pt.category = 'Support'
  pt.department = 'Customer Success'
  pt.description = 'Provide exceptional customer support and help resolve customer issues. You will be the first point of contact for our customers.'
  pt.requirements = '• 1+ years of customer support experience\n• Strong communication skills\n• Ability to work in a fast-paced environment\n• Empathetic and patient'
  pt.location_type = 'remote'
  pt.employment_type = 'full_time'
  pt.education_requirement = 'high_school'
  pt.status = :active
end

# Adidas position templates
adidas_template1 = PositionTemplate.find_or_create_by!(brand: adidas, name: 'Software Engineer') do |pt|
  pt.job_title = 'Software Engineer'
  pt.category = 'Engineering'
  pt.department = 'Product Development'
  pt.description = 'We are looking for a talented Software Engineer to join our team. You will work on building scalable applications and solving complex technical challenges.'
  pt.requirements = '• 3+ years of experience in software development\n• Strong knowledge of Ruby on Rails\n• Experience with PostgreSQL\n• Excellent problem-solving skills'
  pt.location_type = 'hybrid'
  pt.employment_type = 'full_time'
  pt.education_requirement = 'bachelor'
  pt.status = :active
end

adidas_template2 = PositionTemplate.find_or_create_by!(brand: adidas, name: 'Sales Representative') do |pt|
  pt.job_title = 'Sales Representative'
  pt.category = 'Sales'
  pt.department = 'Sales'
  pt.description = 'Join our sales team and help drive revenue growth. You will manage client relationships and close deals.'
  pt.requirements = '• 2+ years of sales experience\n• Excellent communication skills\n• Proven track record of meeting sales targets\n• Customer-focused mindset'
  pt.location_type = 'onsite'
  pt.employment_type = 'full_time'
  pt.education_requirement = 'high_school'
  pt.status = :active
end

adidas_template3 = PositionTemplate.find_or_create_by!(brand: adidas, name: 'Customer Support Specialist') do |pt|
  pt.job_title = 'Customer Support Specialist'
  pt.category = 'Support'
  pt.department = 'Customer Success'
  pt.description = 'Provide exceptional customer support and help resolve customer issues. You will be the first point of contact for our customers.'
  pt.requirements = '• 1+ years of customer support experience\n• Strong communication skills\n• Ability to work in a fast-paced environment\n• Empathetic and patient'
  pt.location_type = 'remote'
  pt.employment_type = 'full_time'
  pt.education_requirement = 'high_school'
  pt.status = :active
end

puts "✅ Created position templates for both brands"

# =============================================================================
# JOB POSTINGS
# =============================================================================

# Note: Job postings are created via API in the application, but we'll create them here for seed data
# We need to set Current.brand for each brand to ensure proper scoping

# Nike job postings
Current.brand = nike

nike_posting1 = JobPosting.find_or_create_by!(
  brand: nike,
  position_template: nike_template1,
  location: nike_vancouver,
  hiring_process: nike_process,
  job_title: 'Software Engineer - Backend'
) do |jp|
  jp.description = nike_template1.description
  jp.requirements = nike_template1.requirements
  jp.status = :published
  jp.published_at = 1.week.ago
end

nike_posting2 = JobPosting.find_or_create_by!(
  brand: nike,
  position_template: nike_template2,
  location: nike_toronto,
  hiring_process: nike_process,
  job_title: 'Sales Representative - Toronto'
) do |jp|
  jp.description = nike_template2.description
  jp.requirements = nike_template2.requirements
  jp.status = :published
  jp.published_at = 3.days.ago
end

# Adidas job postings
Current.brand = adidas

adidas_posting1 = JobPosting.find_or_create_by!(
  brand: adidas,
  position_template: adidas_template1,
  location: adidas_vancouver,
  hiring_process: adidas_process,
  job_title: 'Software Engineer - Full Stack'
) do |jp|
  jp.description = adidas_template1.description
  jp.requirements = adidas_template1.requirements
  jp.status = :published
  jp.published_at = 1.week.ago
end

adidas_posting2 = JobPosting.find_or_create_by!(
  brand: adidas,
  position_template: adidas_template2,
  location: adidas_toronto,
  hiring_process: adidas_process,
  job_title: 'Sales Representative - Toronto'
) do |jp|
  jp.description = adidas_template2.description
  jp.requirements = adidas_template2.requirements
  jp.status = :published
  jp.published_at = 5.days.ago
end

Current.brand = nil

puts "✅ Created job postings for both brands"

puts "\n🎉 Seeding complete!"
puts "   - Brands: 2"
puts "   - Locations: 4 (2 per brand)"
puts "   - Users: 8 (4 per brand)"
puts "   - Hiring Processes: 2 (1 per brand with 4 stages each)"
puts "   - Position Templates: 6 (3 per brand)"
puts "   - Job Postings: 4 (2 per brand)"
