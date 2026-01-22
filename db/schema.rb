# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_01_21_205648) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "applicants", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "preferred_language", default: "en"
    t.string "source"
    t.boolean "flagged", default: false
    t.text "flag_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "created_at"], name: "index_applicants_on_brand_and_created_at"
    t.index ["brand_id", "email"], name: "index_applicants_on_brand_and_email", unique: true
    t.index ["brand_id"], name: "index_applicants_on_brand_id"
  end

  create_table "application_stage_transitions", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.bigint "from_stage_id"
    t.bigint "to_stage_id", null: false
    t.bigint "transitioned_by_id"
    t.datetime "transitioned_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id", "transitioned_at"], name: "index_app_stage_transitions_on_app_and_time"
    t.index ["application_id"], name: "index_application_stage_transitions_on_application_id"
    t.index ["from_stage_id"], name: "index_application_stage_transitions_on_from_stage_id"
    t.index ["to_stage_id"], name: "index_application_stage_transitions_on_to_stage_id"
    t.index ["transitioned_by_id"], name: "index_application_stage_transitions_on_transitioned_by_id"
  end

  create_table "applications", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "applicant_id", null: false
    t.bigint "job_posting_id", null: false
    t.bigint "hiring_process_id", null: false
    t.bigint "current_stage_id"
    t.integer "status", default: 0, null: false
    t.datetime "applied_at", null: false
    t.datetime "hired_at"
    t.bigint "hired_by_id"
    t.datetime "rejected_at"
    t.bigint "rejected_by_id"
    t.text "rejection_reason"
    t.datetime "archived_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applicant_id", "job_posting_id"], name: "index_applications_on_applicant_and_job_posting", unique: true
    t.index ["applicant_id"], name: "index_applications_on_applicant_id"
    t.index ["brand_id", "applicant_id"], name: "index_applications_on_brand_and_applicant"
    t.index ["brand_id", "created_at"], name: "index_applications_on_brand_and_created_at"
    t.index ["brand_id", "job_posting_id"], name: "index_applications_on_brand_and_job_posting"
    t.index ["brand_id", "status"], name: "index_applications_on_brand_and_status"
    t.index ["brand_id"], name: "index_applications_on_brand_id"
    t.index ["current_stage_id"], name: "index_applications_on_current_stage_id"
    t.index ["hired_by_id"], name: "index_applications_on_hired_by_id"
    t.index ["hiring_process_id"], name: "index_applications_on_hiring_process_id"
    t.index ["job_posting_id"], name: "index_applications_on_job_posting_id"
    t.index ["rejected_by_id"], name: "index_applications_on_rejected_by_id"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_brands_on_name"
    t.index ["subdomain"], name: "index_brands_on_subdomain", unique: true
  end

  create_table "hiring_processes", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "is_default", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "active"], name: "index_hiring_processes_on_brand_and_active"
    t.index ["brand_id", "is_default"], name: "index_hiring_processes_on_brand_and_default"
    t.index ["brand_id"], name: "index_hiring_processes_on_brand_id"
  end

  create_table "hiring_stages", force: :cascade do |t|
    t.bigint "hiring_process_id", null: false
    t.string "name", null: false
    t.integer "stage_type", default: 0, null: false
    t.integer "position", null: false
    t.boolean "required", default: true, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hiring_process_id", "position"], name: "index_hiring_stages_on_process_and_position", unique: true
    t.index ["hiring_process_id"], name: "index_hiring_stages_on_hiring_process_id"
  end

  create_table "job_postings", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "position_template_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "location_id", null: false
    t.bigint "hiring_process_id", null: false
    t.string "job_title", null: false
    t.text "description"
    t.text "requirements"
    t.integer "status", default: 0, null: false
    t.datetime "published_at"
    t.datetime "unpublished_at"
    t.datetime "closed_at"
    t.index ["brand_id", "location_id"], name: "index_job_postings_on_brand_and_location"
    t.index ["brand_id", "published_at"], name: "index_job_postings_on_brand_and_published_at"
    t.index ["brand_id", "status"], name: "index_job_postings_on_brand_and_status"
    t.index ["brand_id"], name: "index_job_postings_on_brand_id"
    t.index ["hiring_process_id"], name: "index_job_postings_on_hiring_process_id"
    t.index ["location_id"], name: "index_job_postings_on_location_id"
    t.index ["position_template_id"], name: "index_job_postings_on_position_template_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "location_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_location_assignments_on_location_id"
    t.index ["user_id", "location_id"], name: "index_location_assignments_on_user_id_and_location_id", unique: true
    t.index ["user_id"], name: "index_location_assignments_on_user_id"
  end

  create_table "locations", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.string "name", null: false
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "US"
    t.string "timezone", default: "UTC", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "city", "state"], name: "index_locations_on_brand_city_state"
    t.index ["brand_id", "name"], name: "index_locations_on_brand_and_name"
    t.index ["brand_id"], name: "index_locations_on_brand_id"
  end

  create_table "position_templates", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.string "name", null: false
    t.string "job_title", null: false
    t.string "category", null: false
    t.string "department", null: false
    t.text "description"
    t.text "requirements"
    t.string "location_type"
    t.string "employment_type"
    t.string "education_requirement"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "category"], name: "index_position_templates_on_brand_id_and_category"
    t.index ["brand_id", "created_at"], name: "index_position_templates_on_brand_id_and_created_at"
    t.index ["brand_id", "status"], name: "index_position_templates_on_brand_id_and_status"
    t.index ["brand_id"], name: "index_position_templates_on_brand_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.bigint "brand_id", null: false
    t.integer "role", default: 3, null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "email"], name: "index_users_on_brand_id_and_email", unique: true
    t.index ["brand_id", "role"], name: "index_users_on_brand_id_and_role"
    t.index ["brand_id"], name: "index_users_on_brand_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "applicants", "brands"
  add_foreign_key "application_stage_transitions", "applications"
  add_foreign_key "application_stage_transitions", "hiring_stages", column: "from_stage_id"
  add_foreign_key "application_stage_transitions", "hiring_stages", column: "to_stage_id"
  add_foreign_key "application_stage_transitions", "users", column: "transitioned_by_id"
  add_foreign_key "applications", "applicants"
  add_foreign_key "applications", "brands"
  add_foreign_key "applications", "hiring_processes"
  add_foreign_key "applications", "hiring_stages", column: "current_stage_id"
  add_foreign_key "applications", "job_postings"
  add_foreign_key "applications", "users", column: "hired_by_id"
  add_foreign_key "applications", "users", column: "rejected_by_id"
  add_foreign_key "hiring_processes", "brands"
  add_foreign_key "hiring_stages", "hiring_processes"
  add_foreign_key "job_postings", "brands"
  add_foreign_key "job_postings", "hiring_processes"
  add_foreign_key "job_postings", "locations"
  add_foreign_key "job_postings", "position_templates"
  add_foreign_key "location_assignments", "locations"
  add_foreign_key "location_assignments", "users"
  add_foreign_key "locations", "brands"
  add_foreign_key "position_templates", "brands"
  add_foreign_key "users", "brands"
end
