// cloudinary-list.js
const cloudinary = require('cloudinary').v2;

cloudinary.config({
  cloud_name: 'dcavbnkzz',
  api_key: '974783133285574',
  api_secret: 'AUoN9Bd1eXwl8ndqrWHzByCGYD8',
});

app.get('/api/videos/:folder', async (req, res) => {
  try {
    const folder = req.params.folder;
    const result = await cloudinary.search
      .expression(`resource_type:video AND folder:videos/${folder}`)
      .sort_by('created_at', 'desc')
      .max_results(20)
      .execute();
    
    const videos = result.resources.map(video => ({
      title: video.public_id.split('/').last,
      url: video.secure_url,
    }));

    res.json(videos);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
