# Russell Kosovsky 9/22/23

import random

class Perceptron:
    
    def __init__(self, num_inputs):
        self.weights = []
        # append weights as random values between -1 and 1.
        # num_inputs + 1 because of the weight for bias (threshold).
        for _ in range(num_inputs + 1):
           self.weights.append(random.uniform(-1, 1))
        
    def set_weights(self, new_weights):
        # set the weights of the perceptron manually.
        self.weights = new_weights[:]

    def predict(self, inputs):
        # constant -1 input for the threshold weight.
        inputs.append(-1)
        # this is the dot product between the weights and the inputs.
        weighted_sum = 0
        for i in range(len(self.weights)):
            weighted_sum += self.weights[i] * inputs[i]
        # the activation function determines the output. 
        return self.activation(weighted_sum)

    def activation(self, x):
        # if the weighted sum is positive, output 1, otherwise, output 0.
        if x > 0:
            return 1
        else:
            return 0

    def train(self, training_inputs, outcome, learning_rate = 0.1, rounds = 1000):
        for round in range(rounds):
            for i in range(len(training_inputs)):
                # copy the input to avoid altering the original list.
                inputs = training_inputs[i][:]
                # extract the corresponding outcomes for the input.
                expected_outcome = outcome[i]
                # make a prediction using the current weights.
                prediction = self.predict(inputs)
                # compute the error: difference between label and prediction.
                error = expected_outcome - prediction
                # add bias input for the weight update.
                inputs.append(-1)
                # adjust each weight in the direction to reduce the error using the perceptron rule.
                for j in range(len(self.weights)):
                    self.weights[j] += learning_rate * error * inputs[j]


if __name__ == "__main__":
    
    # generate all 32 possible inputs for a 5-input binary perceptron.
    training_inputs = []
    for i in range(32):
        bits = [int(b) for b in format(i, '05b')]
        training_inputs.append(bits)

    # generate desired outputs based on the specified input patterns.
    desired_outputs = []
    for inp in training_inputs:
        if inp in [[0,1,1,1,1], [1,0,1,1,1], [1,1,0,1,1], [1,1,1,0,1], [1,1,1,1,0], [1,1,1,1,1]]:
            desired_outputs.append(1)
                    
        else:
            desired_outputs.append(0)

    manual_weights = [0.1, 0.3, 0.4, 0.3, 0.3, 1.0]

    perceptron = Perceptron(num_inputs = 5)
    perceptron.set_weights(manual_weights)
    print("Testing with manually set weights...")
    for i in range(len(training_inputs)):
        inputs = training_inputs[i][:]
        desired_output = desired_outputs[i]
        print("Input:", inputs, "-> Predicted Output:", perceptron.predict(inputs), ", Desired Output:", desired_output)

    trained_perceptron = Perceptron(num_inputs = 5)
    trained_perceptron.train(training_inputs, desired_outputs, rounds = 1000)
    print("\nTesting with trained weights...")
    for i in range(len(training_inputs)):
        inputs = training_inputs[i][:]
        desired_output = desired_outputs[i]
        print("Input:", inputs, "-> Predicted Output:", trained_perceptron.predict(inputs), ", Desired Output:", desired_output)
    
    print("\nFinal weights:", trained_perceptron.weights, "\n")
