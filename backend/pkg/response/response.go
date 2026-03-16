package response

import "github.com/gin-gonic/gin"

// Success writes a standard success response envelope.
func Success(c *gin.Context, code int, data interface{}) {
	c.JSON(code, data)
}

// Error writes a standard error response envelope.
func Error(c *gin.Context, code int, message string) {
	c.JSON(code, gin.H{"error": message})
}
