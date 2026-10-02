import unittest
from tiny_poc import Game


class GameTests(unittest.TestCase):
    def test_move_attack_death_reset(self):
        g = Game()
        g.click(1, 2)
        g.click(2, 2)
        self.assertEqual((g.selected.x, g.selected.y), (2, 2))
        g.click(3, 2)
        self.assertEqual(g.at(3, 2).hp, 3)
        g.click(3, 2)
        self.assertIsNone(g.at(3, 2))
        g.click(3, 2)
        self.assertEqual(g.at(3, 2), g.selected)
        g.reset()
        self.assertEqual(g.at(3, 2).hp, 6)
        self.assertIsNone(g.selected)
        self.assertEqual(g.actions, 0)

    def test_invalid_actions_and_switch(self):
        g = Game()
        g.click(3, 2)
        g.click(1, 2)
        g.click(5, 0)
        g.click(5, 4)
        g.click(-1, 0)
        self.assertEqual(g.actions, 0)
        self.assertEqual(g.at(3, 2).hp, 6)
        self.assertEqual((g.selected.x, g.selected.y), (1, 2))
        g.click(0, 4)
        self.assertEqual(g.selected.name, '弓士')


if __name__ == '__main__':
    unittest.main()
