package main

import (
	"fmt"
	"math/rand"
)

var adjectives = []string{"aesthetic", "agreeable", "ambitious", "ample", "animated", "apt", "artistic", "authentic", "benevolent", "blithe", "bold", "brave", "bright", "calm", "capable", "celebrated", "cheerful", "classic", "clear", "coherent", "colorful", "comfortable", "confident", "conscientious", "considerate", "contemporary", "cordial", "creative", "crystalline", "cultured", "dazzling", "decisive", "delightful", "desirable", "determined", "diligent", "dynamic", "eager", "earnest", "efficient", "elegant", "eloquent", "empathetic", "energetic", "engaging", "enthralling", "enthusiastic", "excellent", "exceptional", "exuberant", "fanciful", "fantastic", "farsighted", "favorable", "fearless", "flawless", "flourishing", "fortunate", "frank", "friendly", "fulfilling", "generous", "gentle", "genuine", "glamorous", "graceful", "gracious", "grateful", "harmonious", "honest", "hopeful", "humane", "imaginative", "impartial", "impressive", "incandescent", "independent", "ingenious", "innovative", "inspiring", "inventive", "jovial", "judicious", "kind", "knowledgeable", "lavish", "leading", "legendary", "luminous", "magnificent", "majestic", "marvelous", "masterful", "meticulous", "modest", "noble", "optimistic", "peaceful", "persistent", "placid", "peaceful", "perfect", "perceptive", "playful", "pleasant", "plentiful", "poised", "polished", "polite", "popular", "positive", "powerful", "practical", "precious", "precise", "prepared", "prevalent", "priceless", "principled", "productive", "proficient", "profound", "progressive", "prosperous", "punctual", "pure", "quick", "quiet", "radiant", "rational", "realistic", "reasonable", "reflective", "refined", "regal", "reliable", "remarkable", "resourceful", "respectful", "responsible", "rich", "righteous", "robust", "romantic", "sane", "satisfied", "secure", "sensible", "serene", "sharp", "shimmering", "sincere", "skillful", "sleek", "sparkling", "splendid", "stable", "steadfast", "steady", "strategic", "strong", "studious", "sublime", "successful", "sufficient", "superb", "supportive", "supreme", "sure", "sustainable", "sweet", "talented", "tasteful", "thankful", "thoughtful", "thriving", "timeless", "tolerant", "tranquil", "true", "trustworthy", "ultimate", "unassuming", "unbiased", "unique", "uplifting", "useful", "valiant", "valuable", "versatile", "vibrant", "victorious", "visionary", "vivacious", "warm", "welcoming", "wise", "wonderful", "wondrous"}

var colors = []string{"amber", "aquamarine", "beige", "black", "blue", "bronze", "brown", "burgundy", "chocolate", "cobalt", "coral", "crimson", "cyan", "fuchsia", "gold", "gray", "green", "indigo", "ivory", "jade", "lavender", "lemon", "lilac", "lime", "magenta", "maroon", "mauve", "moss", "navy", "ochre", "olive", "orange", "peach", "pink", "platinum", "plum", "purple", "red", "rust", "sapphire", "scarlet", "sienna", "silver", "tan", "teal", "terracotta", "turquoise", "violet", "white", "yellow"}

var animals = []string{"aardvark", "albatross", "alligator", "alpaca", "anaconda", "anchovy", "anteater", "antelope", "armadillo", "aurochs", "baboon", "badger", "barracuda", "bear", "beaver", "bee", "beetle", "beluga", "bison", "blackbird", "boa", "boar", "bobcat", "buffalo", "butterfly", "buzzard", "camel", "capybara", "cardinal", "caribou", "carp", "cat", "caterpillar", "chameleon", "cheetah", "chicken", "chimpanzee", "chinchilla", "chipmunk", "cobra", "coelacanth", "condor", "cow", "coyote", "crab", "crane", "cricket", "crocodile", "crow", "cuckoo", "deer", "dingo", "dog", "dolphin", "donkey", "dragon", "dragonfly", "duck", "eagle", "eel", "elephant", "elk", "emu", "falcon", "ferret", "finch", "fish", "flamingo", "flea", "fly", "fox", "frog", "gazelle", "gecko", "giraffe", "goat", "goose", "gorilla", "grasshopper", "grayling", "grouse", "gull", "hamster", "hare", "hawk", "hedgehog", "heron", "hippopotamus", "hornet", "horse", "hummingbird", "hyena", "ibis", "iguana", "impala", "jackal", "jaguar", "jay", "jellyfish", "kangaroo", "kingfisher", "kiwi", "koala", "kudu", "ladybug", "lamprey", "lark", "lemur", "leopard", "lion", "lizard", "llama", "lobster", "lynx", "macaw", "magpie", "manatee", "mandrill", "marmot", "meerkat", "mink", "mole", "mongoose", "monkey", "moose", "mosquito", "moth", "mouse", "mule", "narwhal", "newt", "nightingale", "octopus", "okapi", "orangutan", "orca", "ostrich", "otter", "owl", "oyster", "panda", "panther", "parrot", "peacock", "pelican", "penguin", "pheasant", "pig", "pigeon", "platypus", "porcupine", "porpoise", "puma", "python", "quail", "rabbit", "raccoon", "ram", "rat", "rattlesnake", "raven", "reindeer", "rhinoceros", "roadrunner", "robin", "salmon", "sandpiper", "sardine", "scorpion", "sea-lion", "seahorse", "seal", "shark", "sheep", "shrew", "shrimp", "skunk", "sloth", "snail", "snake", "sparrow", "spider", "squirrel", "starfish", "stingray", "stork", "swan", "swordfish", "tapir", "tarantula", "tiger", "toad", "tortoise", "toucan", "trout", "turkey", "turtle", "vulture", "wallaby", "walrus", "wasp", "weasel", "whale", "wildebeest", "wolf", "wolverine", "wombat", "woodpecker", "worm", "yak", "zebra", "zebu", "zorilla"}

func GenerateID() string {
	return fmt.Sprintf("%s-%s-%s-%d",
		adjectives[rand.Intn(len(adjectives))],
		colors[rand.Intn(len(colors))],
		animals[rand.Intn(len(animals))],
		rand.Intn(100),
	)
}

func GenerateUniqueID[T any](ids map[string]T) string {
	for {
		id := GenerateID()
		if _, found := ids[id]; !found {
			return id
		}
	}
}
