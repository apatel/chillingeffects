module Ingestor
  class Legacy
    class AttributeMapper

      class EntityNoticeRoleBuilder

        def initialize(attribute_mapper, role_name, name_key, address_key)
          @attribute_mapper = attribute_mapper
          @hash_data = attribute_mapper.hash
          @role_name = role_name
          @name_key = name_key
          @address_key = address_key
        end

        def build
          if hash_data[name_key].to_s.strip.present?
            name = hash_data[name_key].to_s.strip
          else
            name = attribute_mapper.entities[role_name.to_sym]
          end

          if role_name == 'recipient' &&
            name.blank? &&
              attribute_mapper.default_recipient.present?
            name = attribute_mapper.default_recipient
          end

          return unless name.present?

          attributes = { name: clean_entity_name(name) }

          if address_key
            attributes.merge!(address_hash(address_key))
          end

          EntityNoticeRole.new(name: role_name, entity_attributes: attributes)
        end

        private

        attr_reader :attribute_mapper, :hash_data, :role_name, :name_key, :address_key

        def clean_entity_name(name)
          name = name.to_s.strip
          name = get_first_line(name)
          name = remove_broken_fields(name)
          name
        end

        def get_first_line(name)
          name.split(/\r|\n/)[0]
        end

        def remove_broken_fields(name)
          name.split(/url_box/)[0]
        end

        def address_hash(prefix)
          {
            address_line_1: hash_data["#{prefix}_Address1"],
            address_line_2: hash_data["#{prefix}_Address2"],
            city: hash_data["#{prefix}_City"],
            state: hash_data["#{prefix}_State"],
            zip: hash_data["#{prefix}_Zip"],
            country_code: parse_country_code(hash_data["#{prefix}_Country"]),
          }
        end

        def parse_country_code(country_code)
          return country_code if country_code.nil?

          country_code.strip!

          if country_code.length == 2
            country_code
          else
            mapping[country_code] || country_code[0,2]
          end
        end

        def mapping
          {
            'United States' => 'US',
            'USA' => 'US',
          }
        end

      end
    end
  end
end
