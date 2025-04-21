class Product < ApplicationRecord
	  has_many :variants, dependent: :destroy

end
