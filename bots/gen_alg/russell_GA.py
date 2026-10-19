# BASE GA - Russell Kosovsky

# genetic algorithm (GA) that learns all ones for a 64 bit chromosome. 
# allow for any size input string. 
# allow it to randomly generate the initial population or read it in from a file. 
# Do standard selection, crossover, and mutation as discussed in class. 
# every n NUM_GENERATIONS it should save the best individual along with its fitness and the average fitness of the population. 
# after learning, the program should save the final population to a file. 

import random

# Define parameters for the GA
CHROM_LEN = 64  # CHROM_LEN of binary strings
POP_SIZE = 200  # Population size
NUM_GENERATIONS = 1000  # Number of NUM_GENERATIONS
MUT_RATE = 0.001  # Mutation rate
LOG_INTERVAL = 10  # How often to log results
TOURNY_SIZE = 5 # size of tournament

class Chromosome:
    # Initialize a chromosome
    def __init__(self, genes=None, CHROM_LEN=64):
        # If genes are not provided, create a random binary string of the specified length
        if genes is None:
            self.genes = [random.choice([0, 1]) for _ in range(CHROM_LEN)]
        else:
            self.genes = genes
        # Calculate the fitness of this chromosome
        self.fitness = self.calculate_fitness()
    # Fitness function: number of 1s in the binary string
    def calculate_fitness(self):
        return sum(self.genes)

def selection(population,TOURNY_SIZE):
    # Tournament Selection: select a few random individuals and choose the best among them
    best = random.choice(population)
    for _ in range(TOURNY_SIZE - 1):
        competitor = random.choice(population)
        if competitor.fitness > best.fitness:
            best = competitor
    return best

def crossover(parent1, parent2):
    # Standard Crossover that creates its childs gene by selecting each bit from one of the parents (randomly)
    child_genes = []
    for i in range (CHROM_LEN):
        coin = random.randint(0,1)
        if coin >= 0.5:
            child_genes.append(parent1.genes[i])
        else:
            child_genes.append(parent2.genes[i])
    return Chromosome(child_genes)

def mutate(chromosome, MUT_RATE):
    # Bit-flip Mutation: with a small probability, flip each bit
    for i in range(len(chromosome.genes)):
        if random.random() < MUT_RATE:
            chromosome.genes[i] = 1 - chromosome.genes[i]
    # Recalculate the fitness after mutation
    chromosome.fitness = chromosome.calculate_fitness()

def evolve(population, NUM_GENERATIONS, POP_SIZE, LOG_INTERVAL, MUT_RATE):
    # Evolution loop
    for generation in range(NUM_GENERATIONS):

        new_population = []
        # Create a new population
        for _ in range(POP_SIZE):
            parent1 = selection(population, TOURNY_SIZE)
            parent2 = selection(population, TOURNY_SIZE)
            child = crossover(parent1, parent2)
            mutate(child, MUT_RATE)
            new_population.append(child)
        population = new_population

        # Log best and average fitness at intervals
        if generation % LOG_INTERVAL == 0:          
            # individual with highest fitness (closest to CHROME_LEN) is the best individual)
            best_individual = max(population, key=lambda x: x.fitness)
            total_fitness = 0
            for indiv in population: # Loop through each individual in the population
                    total_fitness += indiv.fitness # Add the fitness of the individual to the total
            # Calculate the average fitness by dividing the total by the number of individuals
            average_fitness = total_fitness / len(population)
            # Print the generation number, the best individual's fitness, and the average fitness
            print(f"Generation {generation}: Best Fitness = {best_individual.fitness}, Avg Fitness = {average_fitness}")
    
    return population # Return the final population

def main():
    # Initialize population from file or randomly
    try:
        with open('initial_population.txt', 'r') as f:
            population = [Chromosome(list(map(int, line.strip()))) for line in f]
    except FileNotFoundError:
        population = [Chromosome(CHROM_LEN=CHROM_LEN) for _ in range(POP_SIZE)]
    # Start Training
    final_population = evolve(population, NUM_GENERATIONS, POP_SIZE, LOG_INTERVAL, MUT_RATE)
    # Save the final population to a file
    with open('final_population.txt', 'w') as f:
        for individual in final_population:
            f.write(''.join(map(str, individual.genes)) + '\n')

if __name__ == '__main__':
    main()
