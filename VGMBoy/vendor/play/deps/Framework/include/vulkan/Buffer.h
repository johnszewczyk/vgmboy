#pragma once

#include "Types.h"
#include "Device.h"

namespace Framework
{
	namespace Vulkan
	{
		class CCommandBufferPool;

		class CBuffer
		{
		public:
			        CBuffer() = default;
			        CBuffer(CDevice&, const VkPhysicalDeviceMemoryProperties&, VkBufferUsageFlags, VkMemoryPropertyFlags, VkDeviceSize);
			        CBuffer(const CBuffer&) = delete;
			        CBuffer(CBuffer&&);
			virtual ~CBuffer();
			
			bool IsEmpty() const;
			void Reset();
			
			CBuffer& operator =(const CBuffer&) = delete;
			CBuffer& operator =(CBuffer&&);
			         operator VkBuffer() const;

			VkDeviceMemory GetMemory() const;

			void Read(VkQueue, CCommandBufferPool&, const VkPhysicalDeviceMemoryProperties&, void*);
			void Write(const void*);
			void Write(VkQueue, CCommandBufferPool&, const VkPhysicalDeviceMemoryProperties&, const void*);
			
		private:
			void Create(const VkPhysicalDeviceMemoryProperties&, VkBufferUsageFlags, VkMemoryPropertyFlags, VkDeviceSize);
			void MoveFrom(CBuffer&&);
			
			CDevice* m_device = nullptr;
			VkBuffer m_handle = VK_NULL_HANDLE;
			VkDeviceMemory m_memory = VK_NULL_HANDLE;

			VkDeviceSize m_size = 0;
		};
	}
}
