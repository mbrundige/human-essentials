RSpec.describe DistributionItemizedBreakdownService, type: :service, skip_seed: true do
  let(:distribution_ids) { distributions.pluck(:id) }
  let(:distributions) { create_list(:distribution, 2, :with_items, item_quantity: distribution_per_item, organization: organization) }
  let(:distribution_per_item) { 50 }
  let(:expected_output) do
    distributions.map(&:items).flatten.each_with_object({}) do |item, acc|
      acc[item.name] ||= {}
      acc[item.name] = {
        distributed: distribution_per_item,
        current_onhand: InventoryItem.find_by(item_id: item.id).quantity,
        onhand_minimum: item.on_hand_minimum_quantity,
        below_onhand_minimum: item.on_hand_minimum_quantity > InventoryItem.find_by(item_id: item.id).quantity
      }
    end
  end
  let(:organization) { create(:organization) }

  before do
    # Force one of onhand minimums to be very high so that we can see it turns out true
    distributions.last.items.first.update(on_hand_minimum_quantity: 9999)
  end

  describe ".fetch" do
    subject { service.fetch }
    let(:service) { described_class.new(organization: organization, distribution_ids: distribution_ids) }

    it "should include the break down of items distributed with onhand data" do
      expect(subject).to eq(expected_output)
    end
  end

  describe ".fetch_csv" do
    subject { service.fetch_csv }
    let(:service) { described_class.new(organization: organization, distribution_ids: distribution_ids) }
    
    it "should output the expected output but in CSV format" do
      expected_output_csv = CSV.generate do |csv|
        csv << ["Item", "Total Distribution", "Total On Hand"]

        expected_output.sort_by { |name, value| -value[:distributed] }.each do |key, value|
          csv << [key, value[:distributed], value[:current_onhand]]
        end
      end

      expect(subject).to eq(expected_output_csv)
    end
  end
end