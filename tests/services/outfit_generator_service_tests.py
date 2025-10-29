import unittest
from unittest.mock import Mock, patch
from src.services.outfit_generator_service import OutfitGeneratorService
from src.db.schema import Garment
from src.models.enums import GarmentCategory, Color, Material


class TestOutfitGeneratorService(unittest.TestCase):
    def setUp(self):
        # Create some sample garments for testing
        self.sample_garments = [
            Garment(
                id=1,
                owner=1,
                category=GarmentCategory.SHIRT,
                color=Color.BLUE,
                name="Blue T-Shirt",
                material=Material.COTTON,
                image_url="http://example.com/shirt.jpg",
                dirty=False
            ),
            Garment(
                id=2,
                owner=1,
                category=GarmentCategory.PANTS,
                color=Color.BLACK,
                name="Black Jeans",
                material=Material.DENIM,
                image_url="http://example.com/pants.jpg",
                dirty=False
            )
        ]

        # Mock the environment variables
        self.env_patcher = patch.dict('os.environ', {'API_KEY': 'dummy_key'})
        self.env_patcher.start()

        self.service = OutfitGeneratorService()

    def tearDown(self):
        self.env_patcher.stop()

    @patch('anthropic.Anthropic')
    def test_generate_outfit_success(self, mock_anthropic):
        # Mock the Anthropic client response
        mock_response = Mock()
        mock_response.content = [
            Mock(
                type='tool_use',
                name='print_outfit_garments',
                input={'garments': [1, 2]}  # Both garments selected
            )
        ]
        mock_anthropic.return_value.messages.create.return_value = mock_response

        context = "Create a casual outfit"
        result = self.service.generate_outfit(self.sample_garments, context)

        # Verify the result contains both garments
        self.assertEqual(len(result.garments), 2)
        self.assertEqual({g.id for g in result.garments}, {1, 2})

        # Verify Anthropic client was called with correct parameters
        mock_anthropic.return_value.messages.create.assert_called_once()
        call_kwargs = mock_anthropic.return_value.messages.create.call_args.kwargs
        self.assertEqual(call_kwargs['model'], 'claude-haiku-4-5-20251001')
        self.assertEqual(call_kwargs['max_tokens'], 1000)
        self.assertEqual(call_kwargs['tool_choice'], {
                         "type": "tool", "name": "print_outfit_garments"})

    @patch('anthropic.Anthropic')
    def test_generate_outfit_partial_selection(self, mock_anthropic):
        # Mock response where only one garment is selected
        mock_response = Mock()
        mock_response.content = [
            Mock(
                type='tool_use',
                name='print_outfit_garments',
                input={'garments': [1]}  # Only first garment selected
            )
        ]
        mock_anthropic.return_value.messages.create.return_value = mock_response

        context = "Create a summer outfit"
        result = self.service.generate_outfit(self.sample_garments, context)

        # Verify only one garment was selected
        self.assertEqual(len(result.garments), 1)
        self.assertEqual(result.garments[0].id, 1)

    @patch('anthropic.Anthropic')
    def test_generate_outfit_no_tool_output(self, mock_anthropic):
        # Mock response with no tool output
        mock_response = Mock()
        mock_response.content = [
            Mock(type='text', value='Some response without tool use')
        ]
        mock_anthropic.return_value.messages.create.return_value = mock_response

        context = "Create an outfit"

        # Should raise exception when no tool output is found
        with self.assertRaises(Exception) as context:
            self.service.generate_outfit(self.sample_garments, context)

        self.assertTrue(
            "Error: Something went wrong with Claude API" in str(context.exception))

    @patch('anthropic.Anthropic')
    def test_generate_outfit_empty_garments(self, mock_anthropic):
        # Test with empty garments list
        context = "Create an outfit"
        result = self.service.generate_outfit([], context)

        # Should return empty garments list
        self.assertEqual(len(result.garments), 0)

        # Verify Anthropic client was still called
        mock_anthropic.return_value.messages.create.assert_called_once()


if __name__ == '__main__':
    unittest.main()
