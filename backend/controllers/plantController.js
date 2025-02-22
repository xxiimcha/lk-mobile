const Plant = require('../models/plantModel');
const SeedRequest = require('../models/seedRequestModel');
const mongoose = require('mongoose');

exports.addPlant = async (req, res) => {
  const { userId, plantName } = req.body;

  if (!userId || !plantName) {
    return res.status(400).json({ error: 'User ID and Plant Name are required.' });
  }

  try {
    const newPlant = new Plant({
      userId: new mongoose.Types.ObjectId(userId), // Ensure it's stored as ObjectId
      plantName,
      progress: 0,
    });

    await newPlant.save();
    res.status(201).json({ message: 'Plant added successfully', plant: newPlant });
  } catch (error) {
    console.error('Error adding plant:', error);
    res.status(500).json({ error: 'Server error' });
  }
};

exports.getUserPlants = async (req, res) => {
  try {
    const userId = new mongoose.Types.ObjectId(req.params.userId);
    console.log(`Fetching seed requests for userId: ${userId}`);

    // Fetch all seed requests regardless of status
    const seedRequests = await SeedRequest.find({
      userId,
      status: { $in: ["pending", "approved", "released", "rejected"] } // Include all possible statuses
    }).lean(); // Convert Mongoose documents to raw JSON

    console.log(`Seed requests found: ${seedRequests.length}`, JSON.stringify(seedRequests, null, 2));
    
    res.status(200).json(seedRequests);
  } catch (error) {
    console.error('Error fetching seed requests:', error);
    res.status(500).json({ error: 'Failed to fetch seed requests' });
  }
};
