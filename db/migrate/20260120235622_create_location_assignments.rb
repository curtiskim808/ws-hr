class CreateLocationAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :location_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true

      t.timestamps
    end

    add_index :location_assignments, [:user_id, :location_id], unique: true
  end
end
