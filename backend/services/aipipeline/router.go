package aipipeline

import "github.com/gin-gonic/gin"

// SetupRouter creates the Gin engine for the AI Pipeline Service.
// All endpoints are under /internal/ — this service is not exposed to the frontend.
func SetupRouter(pipeline *PipelineService) *gin.Engine {
	r := gin.Default()

	handler := NewHandler(pipeline)

	internal := r.Group("/internal")
	{
		internal.POST("/analyze", handler.Analyze)
		internal.POST("/profile", handler.Profile)
		internal.POST("/score", handler.Score)
		internal.POST("/avatar", handler.Avatar)
		internal.POST("/chat", handler.Chat)
		internal.POST("/compatibility", handler.Compatibility)
		internal.POST("/character", handler.Character)
	}

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "aipipeline"})
	})

	return r
}
