import java.util.*;
import java.io.*;

class Production extends javaAI {
	// The game runs inside super(args), before instance fields are initialized,
	// so all of the bot's state is static.
	static final int MAX_DEATHS = 3;
	static final int MAX_FRAMES = 2000; // about 2.5 minutes at 14 frames/s, in case the bot never dies
	static List<Integer> genes;
	static int frames = 0;
	static int deaths = 0;
	static boolean wasAlive = false;
	static boolean done = false;
        @Override
        public void AI_loop() {
			if (done) return;
			// Round Check: report the score on stdout for GeneticAlgorithm, which
			// runs each chromosome in its own process and reads this line
			frames++;
			if (deaths >= MAX_DEATHS || frames >= MAX_FRAMES) {
				System.out.println("FITNESS " + selfScore());
				System.out.flush();
				done = true;
				quitAI();
				return;
			}

			// Release Keys
			thrust(0);
			turnLeft(0);
			turnRight(0);
			setPower(25);
			
			// Chromosome (90 bit binary string) Interpretation - WIP
			// genes:
			// int speedLimit = 15; 			// 6 bits
			// int frontLimit = 1500; 			// 6 bits --- (gene * 50)
			// int trackLimit = 450; 			// 6 bits --- (gene * 15)
			// int angleLimitMax = 270; 		// 6 bits --- (gene * 5)
			// int angleLimitMin = 90; 		// 6 bits --- (gene * 5)
			// int backWallLimit = 10; 		// 6 bits
			// int engagementRange = 300; 		// 6 bits --- (gene * 10)
			// int engagementWallDist = 100; 	// 6 bits --- (gene * 5)
			// int trackWallTurningDist = 900; // 6 bits --- (gene * 20)
			// int lowSpeed = 5; 				// 6 bits
			// int mediumSpeed = 10; 			// 6 bits
			// int shotAngleMax = 5; 			// 6 bits
			// int trackWallDanger = 900; 		// 6 bits --- (gene * 20)
			// int trackWallClose = 500; 		// 6 bits --- (gene * 10)
			// int aimCatchDist = 100; 		// 6 bits --- (gene * 3)

			// Example 90-bit string
			 			  		// 33,    42,   38,   51,   38,   27,   22,   26,   45,   22,   50,   42,   51,   33,   26
			//String exmpl_chrom = "100001101010100110110011100110011011010110011010101101010110110010101010110011100001011010"; 
			int speedLimit = genes.get(0);
			int frontLimit = genes.get(1) * 50;
			int trackLimit = genes.get(2) * 15;
			int angleLimitMax = genes.get(3) * 5;
			int angleLimitMin = genes.get(4) * 5;
			int backWallLimit = genes.get(5);
			int engagementRange = genes.get(6) * 10;
			int engagementWallDist = genes.get(7) * 5;
			int trackWallTurningDist = genes.get(8) * 20;
			int lowSpeed = genes.get(9);
			int mediumSpeed = genes.get(10);
			int shotAngleMax = genes.get(11);
			int trackWallDanger = genes.get(12) * 20;
			int trackWallClose = genes.get(13) * 10;
			int aimCatchDist = genes.get(14) * 3;
	
			// Production System
			int heading = (int) selfHeadingDeg();
			int tracking = (int) selfTrackingDeg();
			int speed = (int) selfSpeed();
			int enemyDistance = (int) enemyDistance(0);
			int aimDirection = aimdir(0); // heading that would hit the enemy, -1 if none is tracked
			int aimError = Math.abs(((aimDirection - heading + 540) % 360) - 180); // degrees between heading and aimDirection
			int frontWall = wallFeeler(1000, heading);
			int leftWall = wallFeeler(1000, heading + 90);
			int rightWall = wallFeeler(1000, heading - 90);
			int backWall = wallFeeler(1000, heading + 180);
			int trackWall = wallFeeler(1000, tracking);

			int reverseTracking = (tracking + 180) % 360; // as in expertBot.py

			// Thrusting
			if (frontWall > frontLimit && speed < speedLimit) {
				thrust(1);
			} else if (frontWall > leftWall && frontWall > rightWall && frontWall > backWall && frontWall > trackWall && speed < speedLimit) {
				thrust(1);
			} else if (trackWall < trackLimit && angleLimitMin <= Math.abs(tracking-heading) && Math.abs(tracking-heading) <= angleLimitMax) {
				thrust(1);
			} else if (backWall < backWallLimit) {
				thrust(1);
			}

			// Turning
			if (heading > aimDirection && enemyDistance < engagementRange && trackWall > engagementWallDist) {
				turnRight(1);
			} else if (heading < aimDirection && enemyDistance < engagementRange && trackWall > engagementWallDist) {
				turnLeft(1);
			} else if (leftWall < rightWall && trackWall > trackWallTurningDist && speed > lowSpeed) {
				turnRight(1);
			} else if (leftWall > rightWall && trackWall > trackWallTurningDist && speed > lowSpeed) {
				turnLeft(1);
			} else if (heading > reverseTracking && trackWall < trackWallDanger && speed > mediumSpeed) {
				turnRight(1);
			} else if (heading < reverseTracking && trackWall < trackWallDanger && speed > mediumSpeed) {
				turnLeft(1);
			} else if (leftWall < rightWall && trackWall < trackWallClose) {
				turnRight(1);
			} else if (leftWall > rightWall && trackWall < trackWallClose) {
				turnLeft(1);
			} else if (heading > aimDirection && trackWall > aimCatchDist) {
				turnRight(1);
			} else if (heading < aimDirection && trackWall > aimCatchDist) {
				turnLeft(1);
			} else if (leftWall < rightWall) {
				turnRight(1);
			} else if (leftWall > rightWall) {
				turnLeft(1);
			}

			// Shooting
			if (aimDirection != -1 && aimError < shotAngleMax) {
				fireShot();
			}

			// Round Tracking
			boolean alive = selfAlive() == 1;
			if (wasAlive && !alive) {
				deaths++;
			}
			wasAlive = alive;
        }
		
		// Helper Function that converts a chromosome (90 bits) to a list of  genes (15 genes, each being 6 bits)
    	public static List<Integer> parseChromosome(String chromosome) {
        	List<Integer> genes = new ArrayList<>();
        	for (int i = 0; i < chromosome.length(); i += 6) {
            	String gene = chromosome.substring(i, i + 6);
            	genes.add(Integer.parseInt(gene, 2)); // Convert binary string to integer
        	}
        	return genes;
    	}

		public Production(String args[]) {
			super(args);
		}

      // Usage: java -Djava.library.path=. Production [90-bit chromosome]
      // Without an argument the chromosome is read from chromosome.txt.
      public static void main(String args[]) {
          String chromosome = "";
          if (args.length > 0) {
              chromosome = args[0];
          } else {
              try {
                  Scanner scanner = new Scanner(new File("./chromosome.txt"));
                  chromosome = scanner.nextLine().trim();
                  scanner.close();
              } catch (IOException e) {
                  System.out.println("Error: " + e);
                  System.exit(1);
              }
          }
          if (!chromosome.matches("[01]{90}")) {
              System.out.println("Error: chromosome must be 90 bits of 0/1, got " + chromosome.length() + " characters");
              System.exit(1);
          }
          genes = parseChromosome(chromosome);
          String[] new_args = {"-name","Petko & Co.","-join","localhost"};
          Production production = new Production(new_args);
      }
}
