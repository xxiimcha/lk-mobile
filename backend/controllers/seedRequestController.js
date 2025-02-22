const SeedRequest = require('../models/seedRequestModel');

// Create a new seed request
exports.createSeedRequest = async (req, res) => {
  try {
    const { userId, seedType, description, imagePath } = req.body; // Get imagePath from request body

    const newSeedRequest = new SeedRequest({
      userId,
      seedType,
      description,
      imagePath: imagePath || null, // Use provided URL instead of req.file.path
      status: "pending", // Default status
      createdAt: new Date(),
    });

    await newSeedRequest.save();
    res.status(201).json({
      message: "Seed request created successfully",
      seedRequest: newSeedRequest,
    });

  } catch (error) {
    console.error("Error creating seed request:", error);
    res.status(500).json({ error: "Server error" });
  }
};

// Fetch seed requests by userId
exports.getSeedRequestsByUser = async (req, res) => {
  const { userId } = req.query;

  try {
    const seedRequests = await SeedRequest.find({ userId }).sort({ createdAt: -1 }); // Sort by newest first
    res.status(200).json(seedRequests);
  } catch (error) {
    console.error('Error fetching seed requests:', error);
    res.status(500).json({ error: 'Server error' });
  }
};
